import Foundation

struct Variety: Identifiable, Codable, Hashable {
    var id: String
    var registrationNumber: String?
    var applicationNumber: String?
    var registrationDate: String?
    var applicationDate: String?
    var publicationDate: String?
    var name: String
    var scientificName: String?
    var japaneseName: String?
    var breederRightHolder: String?
    var applicant: String?
    var breedingPlace: String?
    var developer: String?
    var registeredYear: Int?
    var description: String?
    var characteristicsSummary: String?
    var rightDuration: String?
    var usageConditions: String?
    var remarks: String?
    var maffDetailURL: String?
    var aliasNames: [String]
    var originPrefecture: String?
    var skinColor: String?
    var fleshColor: String?
    var brixMin: Double?
    var brixMax: Double?
    var acidityLevel: AcidityLevel
    var harvestStartMonth: Int?
    var harvestEndMonth: Int?
    var tags: [String]
    var deletedAt: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case registrationNumber = "registration_number"
        case applicationNumber = "application_number"
        case registrationDate = "registration_date"
        case applicationDate = "application_date"
        case publicationDate = "publication_date"
        case name
        case scientificName = "scientific_name"
        case japaneseName = "japanese_name"
        case breederRightHolder = "breeder_right_holder"
        case applicant
        case breedingPlace = "breeding_place"
        case developer
        case registeredYear = "registered_year"
        case description
        case characteristicsSummary = "characteristics_summary"
        case rightDuration = "right_duration"
        case usageConditions = "usage_conditions"
        case remarks
        case maffDetailURL = "maff_detail_url"
        case aliasNames = "alias_names"
        case originPrefecture = "origin_prefecture"
        case skinColor = "skin_color"
        case fleshColor = "flesh_color"
        case brixMin = "brix_min"
        case brixMax = "brix_max"
        case acidityLevel = "acidity_level"
        case harvestStartMonth = "harvest_start_month"
        case harvestEndMonth = "harvest_end_month"
        case tags
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        registrationNumber: String? = nil,
        applicationNumber: String? = nil,
        registrationDate: String? = nil,
        applicationDate: String? = nil,
        publicationDate: String? = nil,
        name: String,
        scientificName: String? = nil,
        japaneseName: String? = nil,
        breederRightHolder: String? = nil,
        applicant: String? = nil,
        breedingPlace: String? = nil,
        developer: String? = nil,
        registeredYear: Int? = nil,
        description: String? = nil,
        characteristicsSummary: String? = nil,
        rightDuration: String? = nil,
        usageConditions: String? = nil,
        remarks: String? = nil,
        maffDetailURL: String? = nil,
        aliasNames: [String] = [],
        originPrefecture: String? = nil,
        skinColor: String? = nil,
        fleshColor: String? = nil,
        brixMin: Double? = nil,
        brixMax: Double? = nil,
        acidityLevel: AcidityLevel = .unknown,
        harvestStartMonth: Int? = nil,
        harvestEndMonth: Int? = nil,
        tags: [String] = [],
        deletedAt: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.registrationNumber = registrationNumber
        self.applicationNumber = applicationNumber
        self.registrationDate = registrationDate
        self.applicationDate = applicationDate
        self.publicationDate = publicationDate
        self.name = name
        self.scientificName = scientificName
        self.japaneseName = japaneseName
        self.breederRightHolder = breederRightHolder
        self.applicant = applicant
        self.breedingPlace = breedingPlace
        self.developer = developer
        self.registeredYear = registeredYear
        self.description = description
        self.characteristicsSummary = characteristicsSummary
        self.rightDuration = rightDuration
        self.usageConditions = usageConditions
        self.remarks = remarks
        self.maffDetailURL = maffDetailURL
        self.aliasNames = aliasNames
        self.originPrefecture = originPrefecture
        self.skinColor = skinColor
        self.fleshColor = fleshColor
        self.brixMin = brixMin
        self.brixMax = brixMax
        self.acidityLevel = acidityLevel
        self.harvestStartMonth = harvestStartMonth
        self.harvestEndMonth = harvestEndMonth
        self.tags = tags
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AcidityLevel: String, Codable, CaseIterable, Hashable, Identifiable {
    case low
    case medium
    case high
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: "低め"
        case .medium: "中"
        case .high: "高め"
        case .unknown: "未設定"
        }
    }
}
