//
//  QoSNeutralizingTestCase.swift
//  VoiceKitTests
//
//  Created by OpenAI (assistant) on 2025-10-13.
//  Purpose: Neutralize XCTest thread QoS to avoid Thread Performance Checker
//           priority inversion traps/warnings introduced in Testing Library 1070.
//
//  This file is test-only and has no effect on product code.
//

import XCTest
import Darwin // for pthread_* QoS APIs

/// A XCTestCase base that runs each test at Default QoS to avoid "higher QoS waiting on lower QoS"
/// detections from the Thread Performance Checker.
///
/// Use by subclassing this instead of XCTestCase in tests that trip the checker.
internal class QoSNeutralizingTestCase: XCTestCase {
    override func invokeTest() {
        var oldClass: qos_class_t = QOS_CLASS_DEFAULT
        var oldRelPri: Int32 = 0
        pthread_get_qos_class_np(pthread_self(), &oldClass, &oldRelPri)
        // Drop to Default QoS for the duration of the test
        pthread_set_qos_class_self_np(QOS_CLASS_DEFAULT, 0)
        defer {
            // Restore original QoS
            pthread_set_qos_class_self_np(oldClass, oldRelPri)
        }
        super.invokeTest()
    }
}
