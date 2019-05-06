//
//  Decoder.swift
//  TLSphinx
//
//  Created by Bruno Berisso on 5/29/15.
//  Copyright (c) 2015 Bruno Berisso. All rights reserved.
//

import Foundation
import AVFoundation
import Sphinx


fileprivate enum SpeechStateEnum : CustomStringConvertible {
    case silence
    case speech
    case utterance
    
    var description: String {
        get {
            switch(self) {
            case .silence:
                return "Silence"
            case .speech:
                return "Speech"
            case .utterance:
                return "Utterance"
            }
        }
    }
}


fileprivate extension AVAudioPCMBuffer {

    func toData() -> Data {
        let channels = UnsafeBufferPointer(start: int16ChannelData, count: 1)
        let ch0Data = Data(bytes: UnsafeMutablePointer<int16>(channels[0]),
                           count: Int(frameCapacity * format.streamDescription.pointee.mBytesPerFrame))
        return ch0Data
    }

}


public enum DecodeErrors : Error {
    case CantReadSpeachFile(String)
    case CantSetAudioSession(NSError)
    case CantStartAudioEngine(NSError)
    case CantAddWordsWhileDecodeingSpeech
    case CantConvertAudioFormat
}


public final class Decoder {
    
    fileprivate var psDecoder: OpaquePointer?
    fileprivate var engine: AVAudioEngine!
    fileprivate var speechState: SpeechStateEnum
    
    public init?(config: Config) {
        
        speechState = .silence
        psDecoder = config.cmdLnConf.flatMap(ps_init)

        if psDecoder == nil {
            return nil
        }
    }
    
    deinit {
        let refCount = ps_free(psDecoder)
        assert(refCount == 0, "Can't free decoder because it's shared among instances")
    }
    
    @discardableResult fileprivate func process_raw(_ data: Data) -> CInt {

        let dataLenght = data.count / 2
        let numberOfFrames = data.withUnsafeBytes { (bytes : UnsafePointer<Int16>) -> Int32 in
            ps_process_raw(psDecoder, bytes, dataLenght, SFalse32, SFalse32)
        }
        let hasSpeech = in_speech()
        
        switch (speechState) {
        case .silence where hasSpeech:
            speechState = .speech
        case .speech where !hasSpeech:
            speechState = .utterance
        case .utterance where !hasSpeech:
            speechState = .silence
        default:
            break
        }
        
        return numberOfFrames
    }
    
    fileprivate func in_speech() -> Bool {
        return ps_get_in_speech(psDecoder) == STrue
    }
    
    @discardableResult fileprivate func start_utt() -> Bool {
        return ps_start_utt(psDecoder) == 0
    }
    
    @discardableResult fileprivate func end_utt() -> Bool {
        return ps_end_utt(psDecoder) == 0
    }
    
    fileprivate func get_hyp() -> Hypothesis? {
        var score: int32 = 0

        guard let string = ps_get_hyp(psDecoder, &score) else {
            return nil
        }

        if let text = String(validatingUTF8: string) {
            return Hypothesis(text: text, score: Int(score))
        } else {
            return nil
        }
    }

    fileprivate func hypotesisForSpeech (inFile fileHandle: FileHandle) -> Hypothesis? {

        start_utt()

        let hypothesis = fileHandle.reduceChunks(2048, initial: nil, reducer: {
            (data: Data, partialHyp: Hypothesis?) -> Hypothesis? in

            process_raw(data)

            var resultantHyp = partialHyp
            if speechState == .utterance {

                end_utt()
                resultantHyp = partialHyp + get_hyp()
                start_utt()
            }

            return resultantHyp
        })

        end_utt()

        //Process any pending speech
        if speechState == .speech {
            return hypothesis + get_hyp()
        } else {
            return hypothesis
        }
    }

    public func decodeSpeech (atPath filePath: String, complete: @escaping (Hypothesis?) -> ()) throws {

        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            throw DecodeErrors.CantReadSpeachFile(filePath)
        }

        DispatchQueue.global().async {
            let hypothesis = self.hypotesisForSpeech(inFile:fileHandle)
            fileHandle.closeFile()
            DispatchQueue.main.async {
                complete(hypothesis)
            }
        }
    }
    
    public func startDecodingSpeech (_ utteranceComplete: @escaping (Hypothesis?) -> ()) throws {

        do {
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [])
            } else {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord)
            }
        } catch let error as NSError {
            print("Error setting the shared AVAudioSession: \(error)")
            throw DecodeErrors.CantSetAudioSession(error)
        }

        engine = AVAudioEngine()

        let input = engine.inputNode
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)
        engine.connect(input, to: mixer, format: input.outputFormat(forBus: 0))

        // We forceunwrap this because the docs for AVAudioFormat specify that this constructor return nil when the channels
        // are grater than 2.
        let formatIn = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        let formatOut = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
        guard let bufferMapper = AVAudioConverter(from: formatIn, to: formatOut) else {
            // Returns nil if the format conversion is not possible.
            throw DecodeErrors.CantConvertAudioFormat
        }

        mixer.installTap(onBus: 0, bufferSize: 2048, format: formatIn, block: {
            [unowned self] (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) in

            guard let sphinxBuffer = AVAudioPCMBuffer(pcmFormat: formatOut, frameCapacity: buffer.frameCapacity) else {
                // Returns nil in the following cases:
                //    - if the format has zero bytes per frame (format.streamDescription->mBytesPerFrame == 0)
                //    - if the buffer byte capacity (frameCapacity * format.streamDescription->mBytesPerFrame)
                //    cannot be represented by an uint32_t
                print("Can't create PCM buffer")
                return
            }

            // This is needed because the 'frameLenght' default value is 0 (since iOS 10) and cause the 'convert' call
            // to faile with an error (Error Domain=NSOSStatusErrorDomain Code=-50 "(null)")
            // More here: http://stackoverflow.com/questions/39714244/avaudioconverter-is-broken-in-ios-10
            sphinxBuffer.frameLength = sphinxBuffer.frameCapacity

            do {
                try bufferMapper.convert(to: sphinxBuffer, from: buffer)
            } catch(let error as NSError) {
                print(error)
                return
            }

            let audioData = sphinxBuffer.toData()
            self.process_raw(audioData)

            print("Process: \(buffer.frameLength) frames - \(audioData.count) bytes - sample time: \(time.sampleTime)")

            if self.speechState == .utterance {

                self.end_utt()
                let hypothesis = self.get_hyp()

                DispatchQueue.main.async {
                    utteranceComplete(hypothesis)
                }

                self.start_utt()
            }
        })

        start_utt()

        do {
            try engine.start()
        } catch let error as NSError {
            end_utt()
            print("Can't start AVAudioEngine: \(error)")
            throw DecodeErrors.CantStartAudioEngine(error)
        }
    }

    public func stopDecodingSpeech () {
        engine.stop()
        engine = nil
    }

    public func add(words:Array<(word: String, phones: String)>) throws {

        guard engine == nil || !engine.isRunning else {
            throw DecodeErrors.CantAddWordsWhileDecodeingSpeech
        }

        for (word,phones) in words {
            let update = words.last?.word == word ? STrue32 : SFalse32
            ps_add_word(psDecoder, word, phones, update)
        }
    }
}
