//
//  TestEZCoreData.swift
//  CKL iOS Challenge Tests
//
//  Created by Marcelo Salloum dos Santos on 21/01/19.
//  Copyright © 2019 Marcelo Salloum dos Santos. All rights reserved.
//

import XCTest
import UIKit
import CoreData
@testable import EZCoreData_Example
@testable import EZCoreData


// MARK: - Mocking Core Data:
class TestEZCoreData: XCTestCase {

    let myID = "123456789"

    static let mockPersistantContainer: NSPersistentContainer = {
        
        let container = NSPersistentContainer(name: "Model")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false // Make it simpler in test env
        
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { (description, error) in
            // Check if the data store is in memory
            precondition( description.type == NSInMemoryStoreType )
            
            // Check if creating container wrong
            if let error = error {
                fatalError("Creating an in-mem coordinator failed \(error)")
            }
        }
        return container
    }()
    
    static let context: NSManagedObjectContext = {
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        
        managedObjectContext.persistentStoreCoordinator = TestEZCoreData.mockPersistantContainer.persistentStoreCoordinator
        
        return managedObjectContext
    }()
    
    static let backgroundContext: NSManagedObjectContext = {
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)

        managedObjectContext.parent = context
        
        return managedObjectContext
    }()
    
    var context: NSManagedObjectContext {
        return TestEZCoreData.context
    }
}


// MARK: - Test Methods
extension TestEZCoreData {

    override func setUp() {
        _ = TestEZCoreData.mockPersistantContainer
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testCount() {
        do {
            let articleCount = try Article.count(context: context)
            XCTAssertNotNil(articleCount)
            let tagCount = try Tag.count(context: context)
            XCTAssertNotNil(tagCount)
        } catch let error {
            print(error)
        }
    }


    // Mark: - Test Single Create
    func testArticleCreation() {
        do {
            // Test Count and Save methods
            let initialCount = try Article.count(context: context)
            _ = Article.getOrCreate(attribute: "id", value: myID, context: context)
            try context.save()
            let countPP = try Article.count(context: context)
            XCTAssertEqual(initialCount + 1, countPP)
        } catch let error {
            print(error.localizedDescription)
        }
    }

    // Mark: - Test Delete
    func testDeleteOne() {
        do {
            // Test Count and Save methods
            let initialCount = try Article.count(context: context)
            print(initialCount)
            let article = Article.getOrCreate(attribute: "id", value: myID, context: context)
            try context.save()
            let countPP = try Article.count(context: context)
            print(countPP)
            XCTAssertEqual(initialCount + 1, countPP)

            // Test Delete and Count Methods
            try article?.delete(context: context)
            let finalCount = try Article.count(context: context)
            print(finalCount)
            XCTAssertEqual(countPP - 1, finalCount)
            XCTAssertEqual(initialCount, finalCount)
        } catch let error {
            print(error.localizedDescription)
        }
    }

    func testDeleteAll() {
        try? Article.deleteAll(context: context)
        var countZero = try? Article.count(context: context)
        XCTAssertEqual(countZero, 0)
        
        _ = try? Article.importList(mockArticleListResponseJSON, idKey: "id", shouldSave: true, context: context)
        let countSix = try? Article.count(context: context)
        XCTAssertEqual(countSix, 6)

        try? Article.deleteAll(context: context)
        countZero = try? Article.count(context: context)
        XCTAssertEqual(countZero, 0)
    }
    
    func testDeleteSubset() {
        try? Article.deleteAll(context: context)
        let countZero = try? Article.count(context: context)
        XCTAssertEqual(countZero, 0)
        
        _ = try? Article.importList(mockArticleListResponseJSON, idKey: "id", shouldSave: true, context: context)
        let countSix = try? Article.count(context: context)
        XCTAssertEqual(countSix, 6)
        
        let remainingList = try? Article.readAll(predicate: NSPredicate(format: "id < 3"), context: context)
        let expectedCountSubset = remainingList?.count
        try? Article.deleteAll(except: remainingList, context: context)
        let countSubset = try? Article.count(context: context)
        XCTAssertEqual(countSubset, expectedCountSubset)
    }
    
    // MARK: - Test Creation
    func testCreateAndSave() {
        let newArticle = Article.create(in: TestEZCoreData.backgroundContext)
        var bckgCount = try? Article.count(context: TestEZCoreData.backgroundContext)   // Counts objects in the Background Context
        var fgndCount = try? Article.count(context: context)                            // Counts objects in the Foreground Context
        XCTAssertEqual(bckgCount!, fgndCount! + 1)
        
        newArticle?.save()
        bckgCount = try? Article.count(context: TestEZCoreData.backgroundContext)
        fgndCount = try? Article.count(context: context)
        XCTAssertEqual(bckgCount!, fgndCount!)
    }
    
    func testSave() {
        _ = Article.create(in: TestEZCoreData.backgroundContext, shouldSave: true)
        let bckgCount = try? Article.count(context: TestEZCoreData.backgroundContext)   // Counts objects in the Background Context
        let fgndCount = try? Article.count(context: context)                            // Counts objects in the Foreground Context
        XCTAssertEqual(bckgCount!, fgndCount!)
    }


    // MARK: - Test Import
    func testImportSync() {
        try? Article.deleteAll(context: context)
        let countZero = try? Article.count(context: context)
        XCTAssertEqual(countZero, 0)

        _ = try? Article.importList(mockArticleListResponseJSON, idKey: "id", shouldSave: true, context: context)
        let countSix = try? Article.count(context: context)
        XCTAssertEqual(countSix, 6)
    }

    func testImportAsync() {
        // Initial SetuUp
        try? Article.deleteAll(context: context)
        let countZero = try? Article.count(context: context)
        XCTAssertEqual(countZero, 0)

        // Creating expectations
        let successExpectation = self.expectation(description: "testImportAsync_success")
        let failureExpectation = self.expectation(description: "testImportAsync_failure")
        failureExpectation.isInverted = true

        Article.importList(mockArticleListResponseJSON, idKey: "id", backgroundContext: context) { result in
            switch result {
            case .success(result: _):
                successExpectation.fulfill()
            case .failure(error: _):
                failureExpectation.fulfill()
            }
        }

        // Waits for the expectations
        waitForExpectations(timeout: 1, handler: nil)
        let countSix = try? Article.count(context: self.context)
        XCTAssertEqual(countSix, 6)
    }


    // Mark: - Test Read
    func testReadAll() {
        try? Article.deleteAll(context: context)
        _ = try? Article.importList(mockArticleListResponseJSON, idKey: "id", shouldSave: true, context: context)
        let articles = try? Article.readAll(context: context)
        XCTAssertEqual(articles?.count, 6)
    }
    
    
    func testReadByAttribute() {
        _ = try? Article.importList(mockArticleListResponseJSON, idKey: "id", shouldSave: true, context: context)
        let articles = try? Article.readAllByAttribute("title", value: "Art", context: context)
        XCTAssertEqual(articles?.count, 2)
    }


    func testReadAllAsync() {
        // Initial SetuUp
        try? Article.deleteAll(context: context)
        _ = try? Article.importList(mockArticleListResponseJSON, idKey: "id", shouldSave: true, context: context)
        var articles: [Article] = []

        // Creating expectations
        let successExpectation = self.expectation(description: "testReadAllAsync_success")
        let failureExpectation = self.expectation(description: "testReadAllAsync_failure")
        failureExpectation.isInverted = true

        // Performs the test
        Article.readAll(context: context) { (result) in
            switch result {
            case .success(result: let articleList):
                guard let articleList = articleList else { failureExpectation.fulfill(); return }
                articles = articleList
                successExpectation.fulfill()
            case .failure(error: _):
                failureExpectation.fulfill()
            }
        }

        // Waits for the expectations
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(articles.count, 6)
    }

    // Mark: - Test Read
    func testReadFirst() {
        do {
            try? Article.deleteAll(context: context)
            _ = try Article.importList(mockArticleListResponseJSON, idKey: "id", shouldSave: true, context: context)
            let randId = Int16.random(in: 1 ... 6)
            let article = try Article.readFirst(NSPredicate(format: "id == \(randId)"), context: context)
            XCTAssertEqual(article!.id, randId)
        } catch let error {
            print(error.localizedDescription)
        }
    }
}
