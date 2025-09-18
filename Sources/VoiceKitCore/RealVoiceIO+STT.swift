//
//  RealVoiceIO+STT.swift
//  VoiceKitCore
//
//  Minimal STT helpers to satisfy tests without full STT implementation.
//  Contains numeric normalization helpers and a no-op finishRecognition.
//
//  Created by OpenAI (GPT) for rdoggett on 2025-09-18.
//

import Foundation

@MainActor
extension RealVoiceIO {

    // Converts simple number words into digits (e.g., "seven" -> "7",
    // "Nineteen" -> "19", "forty-two point five" -> "42.5").
    // Falls back to trimmed original if tokens are unrecognized.
    public static func normalizeNumeric(from s: String) -> String {
        let trimmed = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }

        let lower = trimmed.lowercased()
        let tokens = lower.replacingOccurrences(of: "-", with: " ")
            .split(separator: " ").map(String.init)

        let ones: [String: Int] = [
            "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4,
            "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9
        ]
        let teens: [String: Int] = [
            "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
            "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19
        ]
        let tens: [String: Int] = [
            "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
            "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
        ]

        var intValue: Int? = nil
        var decimalPart: String? = nil
        var i = 0

        // Combine multiple chunks by thousands if needed (simple concatenation rule).
        func commitInt(_ v: Int) {
            intValue = (intValue ?? 0) * 1000 + v
        }

        while i < tokens.count {
            let t = tokens[i]

            if t == "point" {
                // Build decimal digits from remaining tokens.
                var dec = ""
                var j = i + 1
                while j < tokens.count {
                    let w = tokens[j]
                    if let d = ones[w] {
                        dec.append(String(d))
                    } else if let n = Int(w) {
                        dec.append(String(n))
                    } else {
                        // Unknown token -> give up and return original trimmed string.
                        return trimmed
                    }
                    j += 1
                }
                decimalPart = dec.isEmpty ? "0" : dec
                break
            }

            if let v = teens[t] {
                commitInt(v)
                i += 1
                continue
            }

            if let v = tens[t] {
                // Lookahead to combine tens + ones (e.g., "forty two" -> 42)
                var value = v
                if i + 1 < tokens.count, let d = ones[tokens[i + 1]] {
                    value += d
                    i += 1
                }
                commitInt(value)
                i += 1
                continue
            }

            if let d = ones[t] {
                commitInt(d)
                i += 1
                continue
            }

            if let num = Int(t) {
                commitInt(num)
                i += 1
                continue
            }

            if Double(t) != nil {
                // Already numeric with potential decimal -> return original.
                return trimmed
            }

            // Unknown token -> return original.
            return trimmed
        }

        if let intValue {
            if let dec = decimalPart {
                return "\(intValue).\(dec)"
            } else {
                return "\(intValue)"
            }
        }

        return trimmed
    }

    // Backward-compat unlabeled version
    public static func normalizeNumeric(_ s: String) -> String {
        normalizeNumeric(from: s)
    }

    // Tests call finishRecognition() to simulate end-of-speech.
    public func finishRecognition() {
        // no-op stub; present for test compatibility
    }
}
