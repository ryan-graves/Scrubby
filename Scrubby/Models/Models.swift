//
//  Models.swift
//  Scrubby
//
//  Created on 6/1/25.
//

import Foundation
import SwiftUI

// MARK: - FindReplacePair Struct
public struct FindReplacePair: Identifiable, Equatable {
    public let id = UUID()
    public var find: String = ""
    public var replace: String = ""
}

// MARK: - FileFormat Enum
public enum FileFormat: String, Codable, CaseIterable {
    case none
    case hyphenated
    case camelCased
    case lowercaseUnderscored
    
    public var displayName: String {
        switch self {
        case .none: return "None"
        case .hyphenated: return "lowercase-hyphenated"
        case .camelCased: return "camelCase"
        case .lowercaseUnderscored: return "snake_case"
        }
    }
}

// MARK: - RenamingStepType
public enum RenamingStepType: Equatable {
    case findReplace(find: String, replace: String)
    case prefix(String)
    case suffix(String)
    case fileFormat(FileFormat)
}

// MARK: - RenamingStep
public struct RenamingStep: Identifiable, Equatable {
    public let id: UUID
    public var type: RenamingStepType
    
    public init(id: UUID = UUID(), type: RenamingStepType) {
        self.id = id
        self.type = type
    }
}

// MARK: - Codable implementation for RenamingStep
extension RenamingStep: Codable {
    enum CodingKeys: String, CodingKey {
        case id, type
    }
    
    enum StepTypeCodingKeys: String, CodingKey {
        case kind, find, replace, value, format
    }
    
    enum StepKind: String, Codable {
        case findReplace, prefix, suffix, fileFormat
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        
        var typeContainer = container.nestedContainer(keyedBy: StepTypeCodingKeys.self, forKey: .type)
        
        switch type {
        case .findReplace(let find, let replace):
            try typeContainer.encode(StepKind.findReplace, forKey: .kind)
            try typeContainer.encode(find, forKey: .find)
            try typeContainer.encode(replace, forKey: .replace)
        case .prefix(let value):
            try typeContainer.encode(StepKind.prefix, forKey: .kind)
            try typeContainer.encode(value, forKey: .value)
        case .suffix(let value):
            try typeContainer.encode(StepKind.suffix, forKey: .kind)
            try typeContainer.encode(value, forKey: .value)
        case .fileFormat(let format):
            try typeContainer.encode(StepKind.fileFormat, forKey: .kind)
            try typeContainer.encode(format, forKey: .format)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        
        let typeContainer = try container.nestedContainer(keyedBy: StepTypeCodingKeys.self, forKey: .type)
        let kind = try typeContainer.decode(StepKind.self, forKey: .kind)
        
        switch kind {
        case .findReplace:
            let find = try typeContainer.decode(String.self, forKey: .find)
            let replace = try typeContainer.decode(String.self, forKey: .replace)
            type = .findReplace(find: find, replace: replace)
        case .prefix:
            let value = try typeContainer.decode(String.self, forKey: .value)
            type = .prefix(value)
        case .suffix:
            let value = try typeContainer.decode(String.self, forKey: .value)
            type = .suffix(value)
        case .fileFormat:
            let format = try typeContainer.decode(FileFormat.self, forKey: .format)
            type = .fileFormat(format)
        }
    }
}

// MARK: - Preset Model
public struct Preset: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var renamingSteps: [RenamingStep]
    public var overwrite: Bool
    public var moveFiles: Bool
    public var createdAt: Date
    
    public init(id: UUID = UUID(),
         name: String,
         renamingSteps: [RenamingStep],
         overwrite: Bool = false,
         moveFiles: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.renamingSteps = renamingSteps
        self.overwrite = overwrite
        self.moveFiles = moveFiles
        self.createdAt = createdAt
    }
    
    public static func ==(lhs: Preset, rhs: Preset) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - ThumbnailSize
public enum ThumbnailSize: String, CaseIterable {
    case small
    case large

    public var size: CGSize {
        switch self {
        case .small:
            return CGSize(width: 24, height: 24)
        case .large:
            return CGSize(width: 128, height: 128)
        }
    }
    
    public var systemImage: String {
        switch self {
        case .small:
            return "square.resize.down"
        case .large:
            return "square.resize.up"
        }
    }
}

// MARK: - PresetError
public enum PresetError: Error, LocalizedError {
    case duplicateName
    case savingFailed
    
    public var errorDescription: String? {
        switch self {
        case .duplicateName:
            return "A preset with this name already exists."
        case .savingFailed:
            return "Failed to save preset."
        }
    }
}
