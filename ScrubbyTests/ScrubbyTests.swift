//
//  ScrubbyTests.swift
//  ScrubbyTests
//
//  Created by Ryan Graves on 2/16/25.
//

import Testing
import FileScrubby

struct ScrubbyTests {

    @Test("RenamingStep findReplace initializes with correct values")
    func testFindReplaceStepInitialization() async throws {
        let step = RenamingStep(type: .findReplace(find: "foo", replace: "bar"))
        if case let .findReplace(find, replace) = step.type {
            #expect(find == "foo")
            #expect(replace == "bar")
        } else {
            #expect(Bool(false), "Expected findReplace type")
        }
    }

    @Test("RenamingStep prefix initializes and encodes correctly")
    func testPrefixStepInitialization() async throws {
        let step = RenamingStep(type: .prefix("pre_"))
        if case let .prefix(prefix) = step.type {
            #expect(prefix == "pre_")
        } else {
            #expect(Bool(false), "Expected prefix type")
        }
    }

    @Test("RenamingStep suffix initializes and encodes correctly")
    func testSuffixStepInitialization() async throws {
        let step = RenamingStep(type: .suffix("_suf"))
        if case let .suffix(suffix) = step.type {
            #expect(suffix == "_suf")
        } else {
            #expect(Bool(false), "Expected suffix type")
        }
    }

    @Test("RenamingStep fileFormat initializes with correct enum")
    func testFileFormatStepInitialization() async throws {
        let step = RenamingStep(type: .fileFormat(.camelCased))
        if case let .fileFormat(format) = step.type {
            #expect(format == .camelCased)
        } else {
            #expect(Bool(false), "Expected fileFormat type")
        }
    }

}
