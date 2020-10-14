////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Combine
import RealmSwift
import XCTest

// Used by testOfflineClientReset
// The naming here is nonstandard as the sync-1.x.realm test file comes from the .NET unit tests.
// swiftlint:disable identifier_name

class SwiftPerson: Object {
    @objc dynamic var _id: ObjectId? = ObjectId.generate()
    @objc dynamic var firstName: String = ""
    @objc dynamic var lastName: String = ""
    @objc dynamic var age: Int = 30

    convenience init(firstName: String, lastName: String) {
        self.init()
        self.firstName = firstName
        self.lastName = lastName
    }

    override class func primaryKey() -> String? {
        return "_id"
    }
}

class SwiftObjectServerTests: SwiftSyncTestCase {
    /// It should be possible to successfully open a Realm configured for sync.
    func testBasicSwiftSync() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: self.appId, user: user)
            XCTAssert(realm.isEmpty, "Freshly synced Realm was not empty...")
        } catch {
            XCTFail("Got an error: \(error)")
        }
    }

    func testBasicSwiftSyncWithNilPartitionValue() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: nil, user: user)
            XCTAssert(realm.isEmpty, "Freshly synced Realm was not empty...")
        } catch {
            XCTFail("Got an error: \(error)")
        }
    }

    /// If client B adds objects to a Realm, client A should see those new objects.
    func testSwiftAddObjects() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: self.appId, user: user)
            if isParent {
                waitForDownloads(for: realm)
                checkCount(expected: 0, realm, SwiftPerson.self)
                executeChild()
                waitForDownloads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
            } else {
                // Add objects
                try realm.write {
                    realm.add(SwiftPerson(firstName: "Ringo", lastName: "Starr"))
                    realm.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realm.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                }
                waitForUploads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
            }
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testSwiftAddObjectsWithNilPartitionValue() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: nil, user: user)
            if isParent {
                waitForDownloads(for: realm)
                checkCount(expected: 0, realm, SwiftPerson.self)
                executeChild()
                waitForDownloads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
            } else {
                // Add objects
                try realm.write {
                    realm.add(SwiftPerson(firstName: "Ringo", lastName: "Starr"))
                    realm.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realm.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                }
                waitForUploads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
            }
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    /// If client B removes objects from a Realm, client A should see those changes.
    func testSwiftDeleteObjects() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: self.appId, user: user)
            if isParent {
                try realm.write {
                    realm.add(SwiftPerson(firstName: "Ringo", lastName: "Starr"))
                    realm.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realm.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                }
                waitForUploads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
                executeChild()
            } else {
                waitForDownloads(for: realm)
                checkCount(expected: 3, realm, SwiftPerson.self)
                try realm.write {
                    realm.deleteAll()
                }
                waitForUploads(for: realm)
                checkCount(expected: 0, realm, SwiftPerson.self)
            }
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    /// A client should be able to open multiple Realms and add objects to each of them.
    func testMultipleRealmsAddObjects() {
        let partitionValueA = self.appId
        let partitionValueB = "bar"
        let partitionValueC = "baz"

        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())

            let realmA = try Realm(configuration: user.configuration(partitionValue: partitionValueA))
            let realmB = try Realm(configuration: user.configuration(partitionValue: partitionValueB))
            let realmC = try Realm(configuration: user.configuration(partitionValue: partitionValueC))

            if self.isParent {
                waitForDownloads(for: realmA)
                waitForDownloads(for: realmB)
                waitForDownloads(for: realmC)

                checkCount(expected: 0, realmA, SwiftPerson.self)
                checkCount(expected: 0, realmB, SwiftPerson.self)
                checkCount(expected: 0, realmC, SwiftPerson.self)
                executeChild()

                waitForDownloads(for: realmA)
                waitForDownloads(for: realmB)
                waitForDownloads(for: realmC)

                checkCount(expected: 3, realmA, SwiftPerson.self)
                checkCount(expected: 2, realmB, SwiftPerson.self)
                checkCount(expected: 5, realmC, SwiftPerson.self)

                XCTAssertEqual(realmA.objects(SwiftPerson.self).filter("firstName == %@", "Ringo").count,
                               1)
                XCTAssertEqual(realmB.objects(SwiftPerson.self).filter("firstName == %@", "Ringo").count,
                               0)
            } else {
                // Add objects.
                try realmA.write {
                    realmA.add(SwiftPerson(firstName: "Ringo", lastName: "Starr"))
                    realmA.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realmA.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                }
                try realmB.write {
                    realmB.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realmB.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                }
                try realmC.write {
                    realmC.add(SwiftPerson(firstName: "Ringo", lastName: "Starr"))
                    realmC.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                    realmC.add(SwiftPerson(firstName: "Paul", lastName: "McCartney"))
                    realmC.add(SwiftPerson(firstName: "George", lastName: "Harrison"))
                    realmC.add(SwiftPerson(firstName: "Pete", lastName: "Best"))
                }

                waitForUploads(for: realmA)
                waitForUploads(for: realmB)
                waitForUploads(for: realmC)

                checkCount(expected: 3, realmA, SwiftPerson.self)
                checkCount(expected: 2, realmB, SwiftPerson.self)
                checkCount(expected: 5, realmC, SwiftPerson.self)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testConnectionState() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: self.appId, user: user)
            let session = realm.syncSession!

            func wait(forState desiredState: SyncSession.ConnectionState) {
                let ex = expectation(description: "Wait for connection state: \(desiredState)")
                let token = session.observe(\SyncSession.connectionState, options: .initial) { s, _ in
                    if s.connectionState == desiredState {
                        ex.fulfill()
                    }
                }
                waitForExpectations(timeout: 5.0)
                token.invalidate()
            }

            wait(forState: .connected)

            session.suspend()
            wait(forState: .disconnected)

            session.resume()
            wait(forState: .connecting)
            wait(forState: .connected)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // MARK: - Client reset

    func testClientReset() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: self.appId, user: user)

            var theError: SyncError?
            let ex = expectation(description: "Waiting for error handler to be called...")
            app.syncManager.errorHandler = { (error, session) in
                if let error = error as? SyncError {
                    theError = error
                } else {
                    XCTFail("Error \(error) was not a sync error. Something is wrong.")
                }
                ex.fulfill()
            }
            user.simulateClientResetError(forSession: self.appId)
            waitForExpectations(timeout: 10, handler: nil)
            XCTAssertNotNil(theError)
            guard let error = theError else { return }
            XCTAssertTrue(error.code == SyncError.Code.clientResetError)
            guard let resetInfo = error.clientResetInfo() else {
                XCTAssertNotNil(error.clientResetInfo())
                return
            }
            XCTAssertTrue(resetInfo.0.contains("mongodb-realm/\(self.appId)/recovered-realms/recovered_realm"))
            XCTAssertNotNil(realm)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testClientResetManualInitiation() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            var theError: SyncError?

            try autoreleasepool {
                let realm = try synchronouslyOpenRealm(partitionValue: self.appId, user: user)
                let ex = expectation(description: "Waiting for error handler to be called...")
                app.syncManager.errorHandler = { (error, session) in
                    if let error = error as? SyncError {
                        theError = error
                    } else {
                        XCTFail("Error \(error) was not a sync error. Something is wrong.")
                    }
                    ex.fulfill()
                }
                user.simulateClientResetError(forSession: self.appId)
                waitForExpectations(timeout: 10, handler: nil)
                XCTAssertNotNil(theError)
                XCTAssertNotNil(realm)
            }
            guard let error = theError else { return }
            let (path, errorToken) = error.clientResetInfo()!
            XCTAssertFalse(FileManager.default.fileExists(atPath: path))
            SyncSession.immediatelyHandleError(errorToken, syncManager: self.app.syncManager)
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }


    // MARK: - Progress notifiers

    let bigObjectCount = 2

    func populateRealm(user: User, partitionValue: String) {
        do {

            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: partitionValue, user: user)
            try! realm.write {
                for _ in 0..<bigObjectCount {
                    realm.add(SwiftPerson(firstName: "Arthur",
                                          lastName: "Jones"))
                }
            }
            waitForUploads(for: realm)
            checkCount(expected: bigObjectCount, realm, SwiftPerson.self)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // FIXME: Dependancy on Stitch deployment
    #if false
    func testStreamingDownloadNotifier() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionKey: "realm_id")
                //return
            }

            var callCount = 0
            var transferred = 0
            var transferrable = 0
            let realm = try synchronouslyOpenRealm(partitionValue: "realm_id", user: user)

            let session = realm.syncSession
            XCTAssertNotNil(session)
            let ex = expectation(description: "streaming-downloads-expectation")
            var hasBeenFulfilled = false

            let token = session!.addProgressNotification(for: .download, mode: .forCurrentlyOutstandingWork) { p in
                callCount += 1
                XCTAssert(p.transferredBytes >= transferred)
                XCTAssert(p.transferrableBytes >= transferrable)
                transferred = p.transferredBytes
                transferrable = p.transferrableBytes
                if p.transferredBytes > 0 && p.isTransferComplete && !hasBeenFulfilled {
                    ex.fulfill()
                    hasBeenFulfilled = true
                }
            }

            // Wait for the child process to upload all the data.
            executeChild()

            waitForExpectations(timeout: 60.0, handler: nil)
            token!.invalidate()
            XCTAssert(callCount > 1)
            XCTAssert(transferred >= transferrable)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }
    #endif

    func testStreamingUploadNotifier() {
        do {
            var transferred = 0
            var transferrable = 0
            let user = try synchronouslyLogInUser(for: basicCredentials())
            let realm = try synchronouslyOpenRealm(partitionValue: self.appId, user: user)
            let session = realm.syncSession
            XCTAssertNotNil(session)
            var ex = expectation(description: "initial upload")
            let token = session!.addProgressNotification(for: .upload, mode: .reportIndefinitely) { p in
                XCTAssert(p.transferredBytes >= transferred)
                XCTAssert(p.transferrableBytes >= transferrable)
                transferred = p.transferredBytes
                transferrable = p.transferrableBytes
                if p.transferredBytes > 0 && p.isTransferComplete {
                    ex.fulfill()
                }
            }
            waitForExpectations(timeout: 10.0, handler: nil)
            ex = expectation(description: "write transaction upload")
            try realm.write {
                for _ in 0..<bigObjectCount {
                    realm.add(SwiftPerson(firstName: "John", lastName: "Lennon"))
                }
            }
            waitForExpectations(timeout: 10.0, handler: nil)
            token!.invalidate()
            XCTAssert(transferred >= transferrable)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // MARK: - Download Realm

    func testDownloadRealm() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: self.appId)
                return
            }

            // Wait for the child process to upload everything.
            executeChild()

            let ex = expectation(description: "download-realm")
            let config = user.configuration(partitionValue: self.appId)
            let pathOnDisk = ObjectiveCSupport.convert(object: config).pathOnDisk
            XCTAssertFalse(FileManager.default.fileExists(atPath: pathOnDisk))
            Realm.asyncOpen(configuration: config) { realm, error in
                XCTAssertNil(error)
                guard let realm = realm else {
                    XCTFail("No realm on async open")
                    ex.fulfill()
                    return
                }
                self.checkCount(expected: self.bigObjectCount, realm, SwiftPerson.self)
                ex.fulfill()
            }
            func fileSize(path: String) -> Int {
                if let attr = try? FileManager.default.attributesOfItem(atPath: path) {
                    return attr[.size] as! Int
                }
                return 0
            }
            XCTAssertFalse(RLMHasCachedRealmForPath(pathOnDisk))
            waitForExpectations(timeout: 10.0, handler: nil)
            XCTAssertGreaterThan(fileSize(path: pathOnDisk), 0)
            XCTAssertFalse(RLMHasCachedRealmForPath(pathOnDisk))
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testDownloadRealmToCustomPath() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: self.appId)
                return
            }

            // Wait for the child process to upload everything.
            executeChild()

            let ex = expectation(description: "download-realm")
            let customFileURL = realmURLForFile("copy")
            var config = user.configuration(partitionValue: self.appId)
            config.fileURL = customFileURL
            let pathOnDisk = ObjectiveCSupport.convert(object: config).pathOnDisk
            XCTAssertEqual(pathOnDisk, customFileURL.path)
            XCTAssertFalse(FileManager.default.fileExists(atPath: pathOnDisk))
            Realm.asyncOpen(configuration: config) { realm, error in
                XCTAssertNil(error)
                self.checkCount(expected: self.bigObjectCount, realm!, SwiftPerson.self)
                ex.fulfill()
            }
            func fileSize(path: String) -> Int {
                if let attr = try? FileManager.default.attributesOfItem(atPath: path) {
                    return attr[.size] as! Int
                }
                return 0
            }
            XCTAssertFalse(RLMHasCachedRealmForPath(pathOnDisk))
            waitForExpectations(timeout: 10.0, handler: nil)
            XCTAssertGreaterThan(fileSize(path: pathOnDisk), 0)
            XCTAssertFalse(RLMHasCachedRealmForPath(pathOnDisk))
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testCancelDownloadRealm() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionValue: self.appId)
                return
            }

            // Wait for the child process to upload everything.
            executeChild()

            // Use a serial queue for asyncOpen to ensure that the first one adds
            // the completion block before the second one cancels it
            RLMSetAsyncOpenQueue(DispatchQueue(label: "io.realm.asyncOpen"))

            let ex = expectation(description: "async open")
            let config = user.configuration(partitionValue: self.appId)
            Realm.asyncOpen(configuration: config) { _, error in
                XCTAssertNotNil(error)
                ex.fulfill()
            }
            let task = Realm.asyncOpen(configuration: config) { _, _ in
                XCTFail("Cancelled completion handler was called")
            }
            task.cancel()
            waitForExpectations(timeout: 10.0, handler: nil)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // FIXME: Dependancy on Stitch deployment
    #if false
    func testAsyncOpenProgress() {
        app().sharedManager().logLevel = .all
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())
            if !isParent {
                populateRealm(user: user, partitionKey: "realm_id")
                return
            }

            // Wait for the child process to upload everything.
            executeChild()
            let ex1 = expectation(description: "async open")
            let ex2 = expectation(description: "download progress")
            let config = user.configuration(partitionValue: "realm_id")
            let task = Realm.asyncOpen(configuration: config) { _, error in
                XCTAssertNil(error)
                ex1.fulfill()
            }

            task.addProgressNotification { progress in
                if progress.isTransferComplete {
                    ex2.fulfill()
                }
            }

            waitForExpectations(timeout: 10.0, handler: nil)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    func testAsyncOpenTimeout() {
        let syncTimeoutOptions = SyncTimeoutOptions()
        syncTimeoutOptions.connectTimeout = 3000
        app().sharedManager().timeoutOptions = syncTimeoutOptions

        // The server proxy adds a 2 second delay, so a 3 second timeout should succeed
        autoreleasepool {
            do {
                let user = try synchronouslyLogInUser(for: basicCredentials())
                let config = user.configuration(partitionValue: "realm_id")
                let ex = expectation(description: "async open")
                Realm.asyncOpen(configuration: config) { _, error in
                    XCTAssertNil(error)
                    ex.fulfill()
                }
                waitForExpectations(timeout: 10.0, handler: nil)
                try synchronouslyLogOutUser(user)
            } catch {
                XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
            }
        }

        self.resetSyncManager()
        self.setupSyncManager()

        // and a 1 second timeout should fail
        autoreleasepool {
            do {
                let user = try synchronouslyLogInUser(for: basicCredentials())
                let config = user.configuration(partitionValue: "realm_id")

                syncTimeoutOptions.connectTimeout = 1000
                app().sharedManager().timeoutOptions = syncTimeoutOptions

                let ex = expectation(description: "async open")
                Realm.asyncOpen(configuration: config) { _, error in
                    XCTAssertNotNil(error)
                    if let error = error as NSError? {
                        XCTAssertEqual(error.code, Int(ETIMEDOUT))
                        XCTAssertEqual(error.domain, NSPOSIXErrorDomain)
                    }
                    ex.fulfill()
                }
                waitForExpectations(timeout: 4.0, handler: nil)
                try synchronouslyLogOutUser(user)
            } catch {
                XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
            }
        }
    }
    #endif

    func testAppCredentialSupport() {
        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.facebook(accessToken: "accessToken")), RLMCredentials(facebookToken: "accessToken"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.google(serverAuthCode: "serverAuthCode")), RLMCredentials(googleAuthCode: "serverAuthCode"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.apple(idToken: "idToken")), RLMCredentials(appleToken: "idToken"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.emailPassword(email: "email", password: "password")), RLMCredentials(email: "email", password: "password"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.jwt(token: "token")), RLMCredentials(jwt: "token"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.function(payload: ["dog": ["name": "fido"]])),
                       RLMCredentials(functionPayload: ["dog": ["name" as NSString: "fido" as NSString] as NSDictionary]))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.userAPIKey("key")), RLMCredentials(userAPIKey: "key"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.serverAPIKey("key")), RLMCredentials(serverAPIKey: "key"))

        XCTAssertEqual(ObjectiveCSupport.convert(object: Credentials.anonymous), RLMCredentials.anonymous())
    }

    // MARK: - Authentication

    func testInvalidCredentials() {
        do {
            let email = "testInvalidCredentialsEmail"
            let credentials = basicCredentials()
            let user = try synchronouslyLogInUser(for: credentials)
            XCTAssertEqual(user.state, .loggedIn)

            let credentials2 = Credentials.emailPassword(email: email, password: "NOT_A_VALID_PASSWORD")
            let ex = expectation(description: "Should log in the user properly")

            self.app.login(credentials: credentials2, completion: { user2, error in
                XCTAssertNil(user2)
                XCTAssertNotNil(error)
                ex.fulfill()
            })

            waitForExpectations(timeout: 10, handler: nil)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    // MARK: - User-specific functionality

    func testUserExpirationCallback() {
        do {
            let user = try synchronouslyLogInUser(for: basicCredentials())

            // Set a callback on the user
            var blockCalled = false
            let ex = expectation(description: "Error callback should fire upon receiving an error")
            app.syncManager.errorHandler = { (error, _) in
                XCTAssertNotNil(error)
                blockCalled = true
                ex.fulfill()
            }

            // Screw up the token on the user.
            manuallySetAccessToken(for: user, value: badAccessToken())
            manuallySetRefreshToken(for: user, value: badAccessToken())
            // Try to open a Realm with the user; this will cause our errorHandler block defined above to be fired.
            XCTAssertFalse(blockCalled)
            _ = try immediatelyOpenRealm(partitionValue: "realm_id", user: user)

            waitForExpectations(timeout: 10.0, handler: nil)
        } catch {
            XCTFail("Got an error: \(error) (process: \(isParent ? "parent" : "child"))")
        }
    }

    private func realmURLForFile(_ fileName: String) -> URL {
        let testDir = RLMRealmPathForFile("mongodb-realm")
        let directory = URL(fileURLWithPath: testDir, isDirectory: true)
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    // MARK: - App tests

    let appName = "translate-utwuv"

    private func appConfig() -> AppConfiguration {

        return AppConfiguration(baseURL: "http://localhost:9090",
                                transport: nil,
                                localAppName: "auth-integration-tests",
                                localAppVersion: "20180301")
    }

    func testAppInit() {
        let appWithNoConfig = App(id: appName)
        XCTAssertEqual(appWithNoConfig.allUsers.count, 0)

        let appWithConfig = App(id: appName, configuration: appConfig())
        XCTAssertEqual(appWithConfig.allUsers.count, 0)
    }

    func testAppLogin() {

        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        var syncUser: User?

        app.login(credentials: Credentials.emailPassword(email: email, password: password)) { (user, error) in
            XCTAssertNil(error)
            syncUser = user
            loginEx.fulfill()
        }

        wait(for: [loginEx], timeout: 4.0)

        XCTAssertEqual(syncUser?.id, app.currentUser?.id)
        XCTAssertEqual(app.allUsers.count, 1)
    }

    func testAppSwitchAndRemove() {

        let email1 = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password1 = randomString(10)
        let email2 = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password2 = randomString(10)

        let registerUser1Ex = expectation(description: "Register user 1")
        let registerUser2Ex = expectation(description: "Register user 2")

        app.emailPasswordAuth.registerUser(email: email1, password: password1) { (error) in
            XCTAssertNil(error)
            registerUser1Ex.fulfill()
        }

        app.emailPasswordAuth.registerUser(email: email2, password: password2) { (error) in
            XCTAssertNil(error)
            registerUser2Ex.fulfill()
        }

        wait(for: [registerUser1Ex, registerUser2Ex], timeout: 4.0)

        let login1Ex = expectation(description: "Login user 1")
        let login2Ex = expectation(description: "Login user 2")

        var syncUser1: User?
        var syncUser2: User?

        app.login(credentials: Credentials.emailPassword(email: email1, password: password1)) { (user, error) in
            XCTAssertNil(error)
            syncUser1 = user
            login1Ex.fulfill()
        }

        wait(for: [login1Ex], timeout: 4.0)

        app.login(credentials: Credentials.emailPassword(email: email2, password: password2)) { (user, error) in
            XCTAssertNil(error)
            syncUser2 = user
            login2Ex.fulfill()
        }

        wait(for: [login2Ex], timeout: 4.0)

        XCTAssertEqual(app.allUsers.count, 2)

        XCTAssertEqual(syncUser2!.id, app.currentUser!.id)

        app.switch(to: syncUser1!)
        XCTAssertTrue(syncUser1!.id == app.currentUser?.id)

        let removeEx = expectation(description: "Remove user 1")

        syncUser1?.remove { (error) in
            XCTAssertNil(error)
            removeEx.fulfill()
        }

        wait(for: [removeEx], timeout: 4.0)

        XCTAssertEqual(syncUser2!.id, app.currentUser!.id)
        XCTAssertEqual(app.allUsers.count, 1)
    }

    func testAppLinkUser() {

        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        var syncUser: User?

        let credentials = Credentials.emailPassword(email: email, password: password)

        app.login(credentials: Credentials.anonymous) { (user, error) in
            XCTAssertNil(error)
            syncUser = user
            loginEx.fulfill()
        }

        wait(for: [loginEx], timeout: 4.0)

        let linkEx = expectation(description: "Link user")

        syncUser?.linkUser(credentials: credentials) { (user, error) in
            XCTAssertNil(error)
            syncUser = user
            linkEx.fulfill()
        }

        wait(for: [linkEx], timeout: 4.0)

        XCTAssertEqual(syncUser?.id, app.currentUser?.id)
        XCTAssertEqual(syncUser?.identities.count, 2)
    }

    // MARK: - Provider Clients

    func testEmailPasswordProviderClient() {

        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let confirmUserEx = expectation(description: "Confirm user")

        app.emailPasswordAuth.confirmUser("atoken", tokenId: "atokenid") { (error) in
            XCTAssertNotNil(error)
            confirmUserEx.fulfill()
        }
        wait(for: [confirmUserEx], timeout: 4.0)

        let resendEmailEx = expectation(description: "Resend email confirmation")

        app.emailPasswordAuth.resendConfirmationEmail("atoken") { (error) in
            XCTAssertNotNil(error)
            resendEmailEx.fulfill()
        }
        wait(for: [resendEmailEx], timeout: 4.0)

        let resendResetPasswordEx = expectation(description: "Resend reset password email")

        app.emailPasswordAuth.sendResetPasswordEmail("atoken") { (error) in
            XCTAssertNotNil(error)
            resendResetPasswordEx.fulfill()
        }
        wait(for: [resendResetPasswordEx], timeout: 4.0)

        let resetPasswordEx = expectation(description: "Reset password email")

        app.emailPasswordAuth.resetPassword(to: "password", token: "atoken", tokenId: "tokenId") { (error) in
            XCTAssertNotNil(error)
            resetPasswordEx.fulfill()
        }
        wait(for: [resetPasswordEx], timeout: 4.0)

        let callResetFunctionEx = expectation(description: "Reset password function")
        app.emailPasswordAuth.callResetPasswordFunction(email: email,
                                                                       password: randomString(10),
                                                                       args: [[:]]) { (error) in
            XCTAssertNotNil(error)
            callResetFunctionEx.fulfill()
        }
        wait(for: [callResetFunctionEx], timeout: 4.0)
    }

    func testUserAPIKeyProviderClient() {

        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        let credentials = Credentials.emailPassword(email: email, password: password)

        var syncUser: User?
        app.login(credentials: credentials) { (user, error) in
            XCTAssertNil(error)
            syncUser = user
            loginEx.fulfill()
        }

        wait(for: [loginEx], timeout: 4.0)

        let createAPIKeyEx = expectation(description: "Create user api key")

        var apiKey: UserAPIKey?
        syncUser?.apiKeysAuth.createAPIKey(named: "my-api-key") { (key, error) in
            XCTAssertNotNil(key)
            XCTAssertNil(error)
            apiKey = key
            createAPIKeyEx.fulfill()
        }
        wait(for: [createAPIKeyEx], timeout: 4.0)

        let fetchAPIKeyEx = expectation(description: "Fetch user api key")
        syncUser?.apiKeysAuth.fetchAPIKey(apiKey!.objectId) { (key, error) in
            XCTAssertNotNil(key)
            XCTAssertNil(error)
            fetchAPIKeyEx.fulfill()
        }
        wait(for: [fetchAPIKeyEx], timeout: 4.0)

        let fetchAPIKeysEx = expectation(description: "Fetch user api keys")
        syncUser?.apiKeysAuth.fetchAPIKeys(completion: { (keys, error) in
            XCTAssertNotNil(keys)
            XCTAssertEqual(keys!.count, 1)
            XCTAssertNil(error)
            fetchAPIKeysEx.fulfill()
        })
        wait(for: [fetchAPIKeysEx], timeout: 4.0)

        let disableKeyEx = expectation(description: "Disable API key")
        syncUser?.apiKeysAuth.disableAPIKey(apiKey!.objectId) { (error) in
            XCTAssertNil(error)
            disableKeyEx.fulfill()
        }
        wait(for: [disableKeyEx], timeout: 4.0)

        let enableKeyEx = expectation(description: "Enable API key")
        syncUser?.apiKeysAuth.enableAPIKey(apiKey!.objectId) { (error) in
            XCTAssertNil(error)
            enableKeyEx.fulfill()
        }
        wait(for: [enableKeyEx], timeout: 4.0)

        let deleteKeyEx = expectation(description: "Delete API key")
        syncUser?.apiKeysAuth.deleteAPIKey(apiKey!.objectId) { (error) in
            XCTAssertNil(error)
            deleteKeyEx.fulfill()
        }
        wait(for: [deleteKeyEx], timeout: 4.0)
    }

    func testCallFunction() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")

        let credentials = Credentials.emailPassword(email: email, password: password)
        var syncUser: User?
        app.login(credentials: credentials) { (user, error) in
            syncUser = user
            XCTAssertNil(error)
            loginEx.fulfill()
        }
        wait(for: [loginEx], timeout: 4.0)

        let callFunctionEx = expectation(description: "Call function")
        syncUser?.functions.sum([1, 2, 3, 4, 5]) { bson, error in
            guard let bson = bson else {
                XCTFail(error!.localizedDescription)
                return
            }

            guard case let .int64(sum) = bson else {
                XCTFail(error!.localizedDescription)
                return
            }

            XCTAssertNil(error)
            XCTAssertEqual(sum, 15)
            callFunctionEx.fulfill()
        }
        wait(for: [callFunctionEx], timeout: 4.0)
    }

    func testPushRegistration() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginExpectation = expectation(description: "Login user")

        let credentials = Credentials.emailPassword(email: email, password: password)
        app.login(credentials: credentials) { (_, error) in
            XCTAssertNil(error)
            loginExpectation.fulfill()
        }
        wait(for: [loginExpectation], timeout: 4.0)

        let registerDeviceExpectation = expectation(description: "Register Device")
        let client = app.pushClient(serviceName: "gcm")
        client.registerDevice(token: "some-token", user: app.currentUser!) { error in
            XCTAssertNil(error)
            registerDeviceExpectation.fulfill()
        }
        wait(for: [registerDeviceExpectation], timeout: 4.0)

        let dergisterDeviceExpectation = expectation(description: "Deregister Device")
        client.deregisterDevice(user: app.currentUser!, completion: { error in
            XCTAssertNil(error)
            dergisterDeviceExpectation.fulfill()
        })
        wait(for: [dergisterDeviceExpectation], timeout: 4.0)
    }

    func testCustomUserData() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")

        app.emailPasswordAuth.registerUser(email: email, password: password) { (error) in
            XCTAssertNil(error)
            registerUserEx.fulfill()
        }
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        let credentials = Credentials.emailPassword(email: email, password: password)
        var syncUser: User?
        app.login(credentials: credentials) { (user, error) in
            syncUser = user
            XCTAssertNil(error)
            loginEx.fulfill()
        }
        wait(for: [loginEx], timeout: 4.0)

        let userDataEx = expectation(description: "Update user data")
        syncUser?.functions.updateUserData([["favourite_colour": "green", "apples": 10]]) { _, error  in
            XCTAssertNil(error)
            userDataEx.fulfill()
        }
        wait(for: [userDataEx], timeout: 4.0)

        let refreshDataEx = expectation(description: "Refresh user data")
        syncUser?.refreshCustomData { customData, error in
            XCTAssertNil(error)
            XCTAssertNotNil(customData)
            XCTAssertEqual(customData?["apples"] as! Int, 10)
            XCTAssertEqual(customData?["favourite_colour"] as! String, "green")
            refreshDataEx.fulfill()
        }
        wait(for: [refreshDataEx], timeout: 4.0)

        XCTAssertEqual(app.currentUser?.customData["favourite_colour"], .string("green"))
        XCTAssertEqual(app.currentUser?.customData["apples"], .int64(10))
    }

    // MARK: - Mongo Client

    func testMongoClient() {
        let user = try! synchronouslyLogInUser(for: Credentials.anonymous)
        let mongoClient = user.mongoClient("mongodb1")
        XCTAssertEqual(mongoClient.name, "mongodb1")
        let database = mongoClient.database(named: "test_data")
        XCTAssertEqual(database.name, "test_data")
        let collection = database.collection(withName: "Dog")
        XCTAssertEqual(collection.name, "Dog")
    }

    func removeAllFromCollection(_ collection: MongoCollection) {
        let deleteEx = expectation(description: "Delete all from Mongo collection")
        collection.deleteManyDocuments(filter: [:]) { (count, error) in
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            deleteEx.fulfill()
        }
        wait(for: [deleteEx], timeout: 4.0)
    }

    func setupMongoCollection() -> MongoCollection {
        let user = try! synchronouslyLogInUser(for: basicCredentials())
        let mongoClient = user.mongoClient("mongodb1")
        let database = mongoClient.database(named: "test_data")
        let collection = database.collection(withName: "Dog")
        removeAllFromCollection(collection)
        return collection
    }

    func testMongoOptions() {
        let findOptions = FindOptions(1, nil, nil)
        let findOptions1 = FindOptions(5, ["name": 1], ["_id": 1])
        let findOptions2 = FindOptions(5, ["names": ["fido", "bob", "rex"]], ["_id": 1])

        XCTAssertEqual(findOptions.limit, 1)
        XCTAssertEqual(findOptions.projection, nil)
        XCTAssertEqual(findOptions.sort, nil)

        XCTAssertEqual(findOptions1.limit, 5)
        XCTAssertEqual(findOptions1.projection, ["name": 1])
        XCTAssertEqual(findOptions1.sort, ["_id": 1])
        XCTAssertEqual(findOptions2.projection, ["names": ["fido", "bob", "rex"]])

        let findModifyOptions = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        XCTAssertEqual(findModifyOptions.projection, ["name": 1])
        XCTAssertEqual(findModifyOptions.sort, ["_id": 1])
        XCTAssertTrue(findModifyOptions.upsert)
        XCTAssertTrue(findModifyOptions.shouldReturnNewDocument)
    }

    func testMongoInsert() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "tibetan mastiff"]

        let insertOneEx1 = expectation(description: "Insert one document")
        collection.insertOne(document) { (objectId, error) in
            XCTAssertNotNil(objectId)
            XCTAssertNil(error)
            insertOneEx1.fulfill()
        }
        wait(for: [insertOneEx1], timeout: 4.0)

        let insertManyEx1 = expectation(description: "Insert many documents")
        collection.insertMany([document, document2]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 2)
            XCTAssertNil(error)
            insertManyEx1.fulfill()
        }
        wait(for: [insertManyEx1], timeout: 4.0)

        let findEx1 = expectation(description: "Find documents")
        collection.find(filter: [:]) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result?.count, 3)
            XCTAssertEqual(result![0]["name"] as! String, "fido")
            XCTAssertEqual(result![1]["name"] as! String, "fido")
            XCTAssertEqual(result![2]["name"] as! String, "rex")
            findEx1.fulfill()
        }
        wait(for: [findEx1], timeout: 4.0)
    }

    func testMongoFind() {
        let collection = setupMongoCollection()

        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "tibetan mastiff"]
        let document3: Document = ["name": "rex", "breed": "tibetan mastiff", "coat": ["fawn", "brown", "white"]]
        let findOptions = FindOptions(1, nil, nil)

        let insertManyEx1 = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 3)
            XCTAssertNil(error)
            insertManyEx1.fulfill()
        }
        wait(for: [insertManyEx1], timeout: 4.0)

        let findEx1 = expectation(description: "Find documents")
        collection.find(filter: [:]) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result?.count, 3)
            XCTAssertEqual(result![0]["name"] as! String, "fido")
            XCTAssertEqual(result![1]["name"] as! String, "rex")
            XCTAssertEqual(result![2]["name"] as! String, "rex")
            findEx1.fulfill()
        }
        wait(for: [findEx1], timeout: 4.0)

        let findEx2 = expectation(description: "Find documents")
        collection.find(filter: [:], options: findOptions) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result?.count, 1)
            XCTAssertEqual(result![0]["name"] as! String, "fido")
            findEx2.fulfill()
        }
        wait(for: [findEx2], timeout: 4.0)

        let findEx3 = expectation(description: "Find documents")
        collection.find(filter: document3, options: findOptions) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result?.count, 1)
            findEx3.fulfill()
        }
        wait(for: [findEx3], timeout: 4.0)

        let findOneEx1 = expectation(description: "Find one document")
        collection.findOneDocument(filter: document) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            findOneEx1.fulfill()
        }
        wait(for: [findOneEx1], timeout: 4.0)

        let findOneEx2 = expectation(description: "Find one document")
        collection.findOneDocument(filter: document, options: findOptions) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            findOneEx2.fulfill()
        }
        wait(for: [findOneEx2], timeout: 4.0)
    }

    func testMongoFindAndReplace() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]

        let findOneReplaceEx1 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document, replacement: document2) { (result, error) in
            // no doc found, both should be nil
            XCTAssertNil(result)
            XCTAssertNil(error)
            findOneReplaceEx1.fulfill()
        }
        wait(for: [findOneReplaceEx1], timeout: 4.0)

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneReplaceEx2 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document2, replacement: document3, options: options1) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result!["name"] as! String, "john")
            findOneReplaceEx2.fulfill()
        }
        wait(for: [findOneReplaceEx2], timeout: 4.0)

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, false)
        let findOneReplaceEx3 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document, replacement: document2, options: options2) { (result, error) in
            // upsert but do not return document
            XCTAssertNil(result)
            XCTAssertNil(error)
            findOneReplaceEx3.fulfill()
        }
        wait(for: [findOneReplaceEx3], timeout: 4.0)
    }

    func testMongoFindAndUpdate() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]

        let findOneUpdateEx1 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document, update: document2) { (result, error) in
            // no doc found, both should be nil
            XCTAssertNil(result)
            XCTAssertNil(error)
            findOneUpdateEx1.fulfill()
        }
        wait(for: [findOneUpdateEx1], timeout: 4.0)

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneUpdateEx2 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document2, update: document3, options: options1) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result!["name"] as! String, "john")
            findOneUpdateEx2.fulfill()
        }
        wait(for: [findOneUpdateEx2], timeout: 4.0)

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneUpdateEx3 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document, update: document2, options: options2) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result!["name"] as! String, "rex")
            findOneUpdateEx3.fulfill()
        }
        wait(for: [findOneUpdateEx3], timeout: 4.0)
    }

    func testMongoFindAndDelete() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 1)
            XCTAssertNil(error)
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let findOneDeleteEx1 = expectation(description: "Find one document and delete")
        collection.findOneAndDelete(filter: document) { (document, error) in
            // Document does not exist, but should not return an error because of that
            XCTAssertNotNil(document)
            XCTAssertNil(error)
            findOneDeleteEx1.fulfill()
        }
        wait(for: [findOneDeleteEx1], timeout: 4.0)

        // FIXME: It seems there is a possible server bug that does not handle
        // `projection` in `FindOneAndModifyOptions` correctly. The returned error is:
        // "expected pre-image to match projection matcher"
        // https://jira.mongodb.org/browse/REALMC-6878
        /*
        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], false, false)
        let findOneDeleteEx2 = expectation(description: "Find one document and delete")
        collection.findOneAndDelete(filter: document, options: options1) { (document, error) in
            // Document does not exist, but should not return an error because of that
            XCTAssertNil(document)
            XCTAssertNil(error)
            findOneDeleteEx2.fulfill()
        }
        wait(for: [findOneDeleteEx2], timeout: 4.0)
        */

        // FIXME: It seems there is a possible server bug that does not handle
        // `projection` in `FindOneAndModifyOptions` correctly. The returned error is:
        // "expected pre-image to match projection matcher"
        // https://jira.mongodb.org/browse/REALMC-6878
        /*
        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1])
        let findOneDeleteEx3 = expectation(description: "Find one document and delete")
        collection.findOneAndDelete(filter: document, options: options2) { (document, error) in
            XCTAssertNotNil(document)
            XCTAssertEqual(document!["name"] as! String, "fido")
            XCTAssertNil(error)
            findOneDeleteEx3.fulfill()
        }
        wait(for: [findOneDeleteEx3], timeout: 4.0)
        */

        let findEx = expectation(description: "Find documents")
        collection.find(filter: [:]) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            XCTAssertEqual(result?.count, 0)
            findEx.fulfill()
        }
        wait(for: [findEx], timeout: 4.0)
    }

    func testMongoUpdateOne() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        let document5: Document = ["name": "bill", "breed": "great dane"]

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 4)
            XCTAssertNil(error)
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let updateEx1 = expectation(description: "Update one document")
        collection.updateOneDocument(filter: document, update: document2) { (updateResult, error) in
            XCTAssertEqual(updateResult?.matchedCount, 1)
            XCTAssertEqual(updateResult?.modifiedCount, 1)
            XCTAssertNil(updateResult?.objectId)
            XCTAssertNil(error)
            updateEx1.fulfill()
        }
        wait(for: [updateEx1], timeout: 4.0)

        let updateEx2 = expectation(description: "Update one document")
        collection.updateOneDocument(filter: document5, update: document2, upsert: true) { (updateResult, error) in
            XCTAssertEqual(updateResult?.matchedCount, 0)
            XCTAssertEqual(updateResult?.modifiedCount, 0)
            XCTAssertNotNil(updateResult?.objectId)
            XCTAssertNil(error)
            updateEx2.fulfill()
        }
        wait(for: [updateEx2], timeout: 4.0)
    }

    func testMongoUpdateMany() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        let document5: Document = ["name": "bill", "breed": "great dane"]

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 4)
            XCTAssertNil(error)
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let updateEx1 = expectation(description: "Update one document")
        collection.updateManyDocuments(filter: document, update: document2) { (updateResult, error) in
            XCTAssertEqual(updateResult?.matchedCount, 1)
            XCTAssertEqual(updateResult?.modifiedCount, 1)
            XCTAssertNil(updateResult?.objectId)
            XCTAssertNil(error)
            updateEx1.fulfill()
        }
        wait(for: [updateEx1], timeout: 4.0)

        let updateEx2 = expectation(description: "Update one document")
        collection.updateManyDocuments(filter: document5, update: document2, upsert: true) { (updateResult, error) in
            XCTAssertEqual(updateResult?.matchedCount, 0)
            XCTAssertEqual(updateResult?.modifiedCount, 0)
            XCTAssertNotNil(updateResult?.objectId)
            XCTAssertNil(error)
            updateEx2.fulfill()
        }
        wait(for: [updateEx2], timeout: 4.0)
    }

    func testMongoDeleteOne() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]

        let deleteEx1 = expectation(description: "Delete 0 documents")
        collection.deleteOneDocument(filter: document) { (count, error) in
            XCTAssertEqual(count, 0)
            XCTAssertNil(error)
            deleteEx1.fulfill()
        }
        wait(for: [deleteEx1], timeout: 4.0)

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 2)
            XCTAssertNil(error)
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let deleteEx2 = expectation(description: "Delete one document")
        collection.deleteOneDocument(filter: document) { (count, error) in
            XCTAssertEqual(count, 1)
            XCTAssertNil(error)
            deleteEx2.fulfill()
        }
        wait(for: [deleteEx2], timeout: 4.0)
    }

    func testMongoDeleteMany() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]

        let deleteEx1 = expectation(description: "Delete 0 documents")
        collection.deleteManyDocuments(filter: document) { (count, error) in
            XCTAssertEqual(count, 0)
            XCTAssertNil(error)
            deleteEx1.fulfill()
        }
        wait(for: [deleteEx1], timeout: 4.0)

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 2)
            XCTAssertNil(error)
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let deleteEx2 = expectation(description: "Delete one document")
        collection.deleteManyDocuments(filter: ["breed": "cane corso"]) { (count, error) in
            XCTAssertEqual(count, 2)
            XCTAssertNil(error)
            deleteEx2.fulfill()
        }
        wait(for: [deleteEx2], timeout: 4.0)
    }

    func testMongoCountAndAggregate() {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        let insertManyEx1 = expectation(description: "Insert many documents")
        collection.insertMany([document]) { (objectIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objectIds?.count, 1)
            XCTAssertNil(error)
            insertManyEx1.fulfill()
        }
        wait(for: [insertManyEx1], timeout: 4.0)

        collection.aggregate(pipeline: [["$match": ["name": "fido"]], ["$group": ["_id": "$name"]]]) { (result, error) in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
        }

        let countEx1 = expectation(description: "Count documents")
        collection.count(filter: document) { (count, error) in
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            countEx1.fulfill()
        }
        wait(for: [countEx1], timeout: 4.0)

        let countEx2 = expectation(description: "Count documents")
        collection.count(filter: document, limit: 1) { (count, error) in
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            XCTAssertEqual(count, 1)
            countEx2.fulfill()
        }
        wait(for: [countEx2], timeout: 4.0)
    }

    func testWatch() {
        performWatchTest(nil)
    }

    func testWatchAsync() {
        let queue = DispatchQueue.init(label: "io.realm.watchQueue", attributes: .concurrent)
        performWatchTest(queue)
    }

    func performWatchTest(_ queue: DispatchQueue?) {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        var watchEx = expectation(description: "Watch 3 document events")
        let watchTestUtility = WatchTestUtility(targetEventCount: 3, expectation: &watchEx)

        let changeStream: ChangeStream?
        if let queue = queue {
            changeStream = collection.watch(delegate: watchTestUtility, queue: queue)
        } else {
            changeStream = collection.watch(delegate: watchTestUtility)
        }

        DispatchQueue.global().async {
            watchTestUtility.isOpenSemaphore.wait()
            for _ in 0..<3 {
                collection.insertOne(document) { (_, error) in
                    XCTAssertNil(error)
                }
                watchTestUtility.semaphore.wait()
            }
            changeStream?.close()
        }
        wait(for: [watchEx], timeout: 60.0)
    }

    func testWatchWithMatchFilter() {
        performWatchWithMatchFilterTest(nil)
    }

    func testWatchWithMatchFilterAsync() {
        let queue = DispatchQueue.init(label: "io.realm.watchQueue", attributes: .concurrent)
        performWatchWithMatchFilterTest(queue)
    }

    func performWatchWithMatchFilterTest(_ queue: DispatchQueue?) {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        var objectIds = [ObjectId]()
        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { (objIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objIds!.count, 4)
            XCTAssertNil(error)
            objectIds = objIds!.map { $0!.objectIdValue! }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        var watchEx = expectation(description: "Watch 3 document events")
        let watchTestUtility = WatchTestUtility(targetEventCount: 3, matchingObjectId: objectIds.first!, expectation: &watchEx)

        let changeStream: ChangeStream?
        if let queue = queue {
            changeStream = collection.watch(matchFilter: ["fullDocument._id": AnyBSON.objectId(objectIds[0])],
                                            delegate: watchTestUtility,
                                            queue: queue)
        } else {
            changeStream = collection.watch(matchFilter: ["fullDocument._id": AnyBSON.objectId(objectIds[0])],
                                            delegate: watchTestUtility)
        }

        DispatchQueue.global().async {
            watchTestUtility.isOpenSemaphore.wait()
            for i in 0..<3 {
                let name: AnyBSON = .string("fido-\(i)")
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[0])],
                                             update: ["name": name, "breed": "king charles"]) { (_, error) in
                    XCTAssertNil(error)
                }
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[1])],
                                             update: ["name": name, "breed": "king charles"]) { (_, error) in
                    XCTAssertNil(error)
                }
                watchTestUtility.semaphore.wait()
            }
            changeStream?.close()
        }
        wait(for: [watchEx], timeout: 60.0)
    }

    func testWatchWithFilterIds() {
        performWatchWithFilterIdsTest(nil)
    }

    func testWatchWithFilterIdsAsync() {
        let queue = DispatchQueue.init(label: "io.realm.watchQueue", attributes: .concurrent)
        performWatchWithFilterIdsTest(queue)
    }

    func performWatchWithFilterIdsTest(_ queue: DispatchQueue?) {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        var objectIds = [ObjectId]()

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { (objIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objIds?.count, 4)
            XCTAssertNil(error)
            objectIds = objIds!.map { $0!.objectIdValue! }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        var watchEx = expectation(description: "Watch 3 document events")
        let watchTestUtility = WatchTestUtility(targetEventCount: 3,
                                                matchingObjectId: objectIds.first!,
                                                expectation: &watchEx)
        let changeStream: ChangeStream?
        if let queue = queue {
            changeStream = collection.watch(filterIds: [objectIds[0]], delegate: watchTestUtility, queue: queue)
        } else {
            changeStream = collection.watch(filterIds: [objectIds[0]], delegate: watchTestUtility)
        }

        DispatchQueue.global().async {
            watchTestUtility.isOpenSemaphore.wait()
            for i in 0..<3 {
                let name: AnyBSON = .string("fido-\(i)")
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[0])],
                                             update: ["name": name, "breed": "king charles"]) { (_, error) in
                    XCTAssertNil(error)
                }
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[1])],
                                             update: ["name": name, "breed": "king charles"]) { (_, error) in
                    XCTAssertNil(error)
                }
                watchTestUtility.semaphore.wait()
            }
            changeStream?.close()
        }
        wait(for: [watchEx], timeout: 60.0)
    }

    func testWatchMultipleFilterStreams() {
        performMultipleWatchStreamsTest(nil)
    }

    func testWatchMultipleFilterStreamsAsync() {
        let queue = DispatchQueue.init(label: "io.realm.watchQueue", attributes: .concurrent)
        performMultipleWatchStreamsTest(queue)
    }

    func performMultipleWatchStreamsTest(_ queue: DispatchQueue?) {
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        var objectIds = [ObjectId]()

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { (objIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objIds?.count, 4)
            XCTAssertNil(error)
            objectIds = objIds!.map { $0!.objectIdValue! }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        var watchEx = expectation(description: "Watch 5 document events")
        watchEx.expectedFulfillmentCount = 2

        let watchTestUtility1 = WatchTestUtility(targetEventCount: 3,
                                                 matchingObjectId: objectIds[0],
                                                 expectation: &watchEx)

        let watchTestUtility2 = WatchTestUtility(targetEventCount: 3,
                                                 matchingObjectId: objectIds[1],
                                                 expectation: &watchEx)

        let changeStream1: ChangeStream?
        let changeStream2: ChangeStream?

        if let queue = queue {
            changeStream1 = collection.watch(filterIds: [objectIds[0]], delegate: watchTestUtility1, queue: queue)
            changeStream2 = collection.watch(filterIds: [objectIds[1]], delegate: watchTestUtility2, queue: queue)
        } else {
            changeStream1 = collection.watch(filterIds: [objectIds[0]], delegate: watchTestUtility1)
            changeStream2 = collection.watch(filterIds: [objectIds[1]], delegate: watchTestUtility2)
        }

        DispatchQueue.global().async {
            watchTestUtility1.isOpenSemaphore.wait()
            watchTestUtility2.isOpenSemaphore.wait()
            for i in 0..<5 {
                let name: AnyBSON = .string("fido-\(i)")
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[0])],
                                             update: ["name": name, "breed": "king charles"]) { (_, error) in
                    XCTAssertNil(error)
                }
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[1])],
                                             update: ["name": name, "breed": "king charles"]) { (_, error) in
                    XCTAssertNil(error)
                }
                watchTestUtility1.semaphore.wait()
                watchTestUtility2.semaphore.wait()
                if i == 2 {
                    changeStream1?.close()
                    changeStream2?.close()
                }
            }
        }
        wait(for: [watchEx], timeout: 60.0)
    }
}

// XCTest doesn't care about the @available on the class and will try to run
// the tests even on older versions. Putting this check inside `defaultTestSuite`
// results in a warning about it being redundant due to the enclosing check, so
// it needs to be out of line.
func hasCombine() -> Bool {
    if #available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *) {
        return true
    }
    return false
}

@available(OSX 10.15, watchOS 6.0, iOS 13.0, iOSApplicationExtension 13.0, OSXApplicationExtension 10.15, tvOS 13.0, *)
class CombineObjectServerTests: SwiftSyncTestCase {
    override class var defaultTestSuite: XCTestSuite {
        if hasCombine() {
            return super.defaultTestSuite
        }
        return XCTestSuite(name: "\(type(of: self))")
    }

    func setupMongoCollection() -> MongoCollection {
        let user = try! synchronouslyLogInUser(for: basicCredentials())
        let mongoClient = user.mongoClient("mongodb1")
        let database = mongoClient.database(named: "test_data")
        let collection = database.collection(withName: "Dog")
        removeAllFromCollection(collection)
        return collection
    }

    func removeAllFromCollection(_ collection: MongoCollection) {
        let deleteEx = expectation(description: "Delete all from Mongo collection")
        collection.deleteManyDocuments(filter: [:]) { (count, error) in
            XCTAssertNotNil(count)
            XCTAssertNil(error)
            deleteEx.fulfill()
        }
        wait(for: [deleteEx], timeout: 4.0)
    }

    // swiftlint:disable multiple_closures_with_trailing_closure
    func testWatchCombine() {
        let sema = DispatchSemaphore(value: 0)
        let sema2 = DispatchSemaphore(value: 0)
        let openSema = DispatchSemaphore(value: 0)
        let openSema2 = DispatchSemaphore(value: 0)
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        let watchEx1 = expectation(description: "Watch 3 document events")
        watchEx1.expectedFulfillmentCount = 3
        let watchEx2 = expectation(description: "Watch 3 document events")
        watchEx2.expectedFulfillmentCount = 3

        var subscriptions: Set<AnyCancellable> = []

        collection.watch()
            .onOpen {
                openSema.signal()
            }
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .sink(receiveCompletion: { _ in }) { _ in
                watchEx1.fulfill()
                XCTAssertFalse(Thread.isMainThread)
                sema.signal()
            }.store(in: &subscriptions)

        collection.watch()
            .onOpen {
                openSema2.signal()
            }
            .subscribe(on: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { _ in
                watchEx2.fulfill()
                XCTAssertTrue(Thread.isMainThread)
                sema2.signal()
            }.store(in: &subscriptions)

        DispatchQueue.global().async {
            openSema.wait()
            openSema2.wait()
            for i in 0..<3 {
                collection.insertOne(document) { (_, error) in
                    XCTAssertNil(error)
                }
                sema.wait()
                sema2.wait()
                if i == 2 {
                    subscriptions.forEach { $0.cancel() }
                }
            }
        }
        wait(for: [watchEx1, watchEx2], timeout: 60.0)
    }

    func testWatchCombineWithFilterIds() {
        let sema1 = DispatchSemaphore(value: 0)
        let sema2 = DispatchSemaphore(value: 0)
        let openSema1 = DispatchSemaphore(value: 0)
        let openSema2 = DispatchSemaphore(value: 0)
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        var objectIds = [ObjectId]()

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { (objIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objIds?.count, 4)
            XCTAssertNil(error)
            objectIds = objIds!.map { $0!.objectIdValue! }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let watchEx1 = expectation(description: "Watch 3 document events")
        watchEx1.expectedFulfillmentCount = 3
        let watchEx2 = expectation(description: "Watch 3 document events")
        watchEx2.expectedFulfillmentCount = 3
        var subscriptions: Set<AnyCancellable> = []

        collection.watch(filterIds: [objectIds[0]])
            .onOpen {
                openSema1.signal()
            }
            .subscribe(on: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { changeEvent in
                XCTAssertTrue(Thread.isMainThread)
                guard let doc = changeEvent.documentValue else {
                    return
                }

                let objectId = doc["fullDocument"]??.documentValue!["_id"]??.objectIdValue!
                if objectId == objectIds[0] {
                    watchEx1.fulfill()
                    sema1.signal()
                }
        }.store(in: &subscriptions)

        collection.watch(filterIds: [objectIds[1]])
            .onOpen {
                openSema2.signal()
            }
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .sink(receiveCompletion: { _ in }) { (changeEvent) in
                XCTAssertFalse(Thread.isMainThread)
                guard let doc = changeEvent.documentValue else {
                    return
                }

                let objectId = doc["fullDocument"]??.documentValue!["_id"]??.objectIdValue!
                if objectId == objectIds[1] {
                    watchEx2.fulfill()
                    sema2.signal()
                }
        }.store(in: &subscriptions)

        DispatchQueue.global().async {
            openSema1.wait()
            openSema2.wait()
            for i in 0..<3 {
                let name: AnyBSON = .string("fido-\(i)")
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[0])],
                                             update: ["name": name, "breed": "king charles"]) { (_, error) in
                    XCTAssertNil(error)
                }
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[1])],
                                             update: ["name": name, "breed": "king charles"]) { (_, error) in
                    XCTAssertNil(error)
                }
                sema1.wait()
                sema2.wait()
                if i == 2 {
                    subscriptions.forEach { $0.cancel() }
                }
            }
        }
        wait(for: [watchEx1, watchEx2], timeout: 60.0)
    }

    func testWatchCombineWithMatchFilter() {
        let sema1 = DispatchSemaphore(value: 0)
        let sema2 = DispatchSemaphore(value: 0)
        let openSema1 = DispatchSemaphore(value: 0)
        let openSema2 = DispatchSemaphore(value: 0)
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        var objectIds = [ObjectId]()

        let insertManyEx = expectation(description: "Insert many documents")
        collection.insertMany([document, document2, document3, document4]) { (objIds, error) in
            XCTAssertNotNil(objectIds)
            XCTAssertEqual(objIds?.count, 4)
            XCTAssertNil(error)
            objectIds = objIds!.map { $0!.objectIdValue! }
            insertManyEx.fulfill()
        }
        wait(for: [insertManyEx], timeout: 4.0)

        let watchEx1 = expectation(description: "Watch 3 document events")
        watchEx1.expectedFulfillmentCount = 3
        let watchEx2 = expectation(description: "Watch 3 document events")
        watchEx2.expectedFulfillmentCount = 3
        var subscriptions: Set<AnyCancellable> = []

        collection.watch(matchFilter: ["fullDocument._id": AnyBSON.objectId(objectIds[0])])
            .onOpen {
                openSema1.signal()
            }
            .subscribe(on: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { changeEvent in
                XCTAssertTrue(Thread.isMainThread)
                guard let doc = changeEvent.documentValue else {
                    return
                }

                let objectId = doc["fullDocument"]??.documentValue!["_id"]??.objectIdValue!
                if objectId == objectIds[0] {
                    watchEx1.fulfill()
                    sema1.signal()
                }
        }.store(in: &subscriptions)

        collection.watch(matchFilter: ["fullDocument._id": AnyBSON.objectId(objectIds[1])])
            .onOpen {
                openSema2.signal()
            }
            .subscribe(on: DispatchQueue.global())
            .receive(on: DispatchQueue.global())
            .sink(receiveCompletion: { _ in }) { changeEvent in
                XCTAssertFalse(Thread.isMainThread)
                guard let doc = changeEvent.documentValue else {
                    return
                }

                let objectId = doc["fullDocument"]??.documentValue!["_id"]??.objectIdValue!
                if objectId == objectIds[1] {
                    watchEx2.fulfill()
                    sema2.signal()
                }
        }.store(in: &subscriptions)

        DispatchQueue.global().async {
            openSema1.wait()
            openSema2.wait()
            for i in 0..<3 {
                let name: AnyBSON = .string("fido-\(i)")
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[0])],
                                             update: ["name": name, "breed": "king charles"]) { (_, error) in
                    XCTAssertNil(error)
                }
                collection.updateOneDocument(filter: ["_id": AnyBSON.objectId(objectIds[1])],
                                             update: ["name": name, "breed": "king charles"]) { (_, error) in
                    XCTAssertNil(error)
                }
                sema1.wait()
                sema2.wait()
                if i == 2 {
                    subscriptions.forEach { $0.cancel() }
                }
            }
        }
        wait(for: [watchEx1, watchEx2], timeout: 60.0)
    }

    // MARK: - Combine promises

    func testEmailPasswordAuthenticationCombine() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)
        var cancellable = Set<AnyCancellable>()

        let registerUserEx = expectation(description: "Register user")
        app.emailPasswordAuth.registerUser(email: email, password: password)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should register")
                }
            }, receiveValue: { _ in
                registerUserEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [registerUserEx], timeout: 4.0)

        let confirmUserEx = expectation(description: "Confirm user")
        app.emailPasswordAuth.confirmUser("atoken", tokenId: "atokenid")
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    confirmUserEx.fulfill()
                }
            }, receiveValue: { _ in
                XCTFail("Should auto confirm")
            })
            .store(in: &cancellable)
        wait(for: [confirmUserEx], timeout: 4.0)

        let resendEmailEx = expectation(description: "Resend email confirmation")
        app.emailPasswordAuth.resendConfirmationEmail(email: "atoken")
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    resendEmailEx.fulfill()
                }
            }, receiveValue: { _ in
                XCTFail("Should auto confirm")
            })
            .store(in: &cancellable)
        wait(for: [resendEmailEx], timeout: 4.0)

        let sendResetPasswordEx = expectation(description: "Send reset password email")
        app.emailPasswordAuth.sendResetPasswordEmail(email: "atoken")
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    sendResetPasswordEx.fulfill()
                }
            }, receiveValue: { _ in
                XCTFail("Should not send reset password")
            })
            .store(in: &cancellable)
        wait(for: [sendResetPasswordEx], timeout: 4.0)

        let resetPasswordEx = expectation(description: "Reset password email")
        app.emailPasswordAuth.resetPassword(to: "password", token: "atoken", tokenId: "tokenId")
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    resetPasswordEx.fulfill()
                }
            }, receiveValue: { _ in
                XCTFail("Should not reset password")
            })
            .store(in: &cancellable)
        wait(for: [resetPasswordEx], timeout: 4.0)

        let callResetFunctionEx = expectation(description: "Reset password function")
        app.emailPasswordAuth.callResetPasswordFunction(email: email, password: randomString(10), args: [[:]])
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    callResetFunctionEx.fulfill()
                }
            }, receiveValue: { _ in
                XCTFail("Should not call reset password")
            })
            .store(in: &cancellable)
        wait(for: [callResetFunctionEx], timeout: 4.0)
    }

    func testAppLoginCombine() {
        var cancellable = Set<AnyCancellable>()
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")
        app.emailPasswordAuth.registerUser(email: email, password: password)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should register")
                }
            }, receiveValue: { _ in
                registerUserEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        app.login(credentials: Credentials.emailPassword(email: email, password: password))
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should login")
                }
            }, receiveValue: { user in
                loginEx.fulfill()
                XCTAssertEqual(user.id, self.app.currentUser?.id)
            })
            .store(in: &cancellable)
        wait(for: [loginEx], timeout: 4.0)
        XCTAssertEqual(self.app.allUsers.count, 1)
    }

    func testRefreshCustomDataCombine() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)
        var cancellable = Set<AnyCancellable>()

        let registerUserEx = expectation(description: "Register user")
        app.emailPasswordAuth.registerUser(email: email, password: password)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should register")
                }
            }, receiveValue: { _ in
                registerUserEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [registerUserEx], timeout: 4.0)

        let credentials = Credentials.emailPassword(email: email, password: password)
        var syncUser: User!
        let loginEx = expectation(description: "Login user")
        app.login(credentials: credentials)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should login")
                }
            }, receiveValue: { user in
                syncUser = user
                loginEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [loginEx], timeout: 4.0)

        let userDataEx = expectation(description: "Update user data")
        syncUser.functions.updateUserData([["favourite_colour": "green", "apples": 10]]) { _, error  in
            XCTAssertNil(error)
            userDataEx.fulfill()
        }
        wait(for: [userDataEx], timeout: 4.0)

        let refreshDataEx = expectation(description: "Refresh user data")
        syncUser.refreshCustomData()
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should refresh")
                }
            }, receiveValue: { customData in
                XCTAssertEqual(customData["apples"] as! Int, 10)
                XCTAssertEqual(customData["favourite_colour"] as! String, "green")
                refreshDataEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [refreshDataEx], timeout: 4.0)

        XCTAssertEqual(app.currentUser?.customData["favourite_colour"], .string("green"))
        XCTAssertEqual(app.currentUser?.customData["apples"], .int64(10))
    }

    func testMongoCollectionInsertCombine() {
        var cancellable = Set<AnyCancellable>()
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "tibetan mastiff"]

        let insertOneEx1 = expectation(description: "Insert one document")
        collection.insertOne(document)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should insert")
                }
            }, receiveValue: { _ in
                insertOneEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [insertOneEx1], timeout: 4.0)

        let insertManyEx1 = expectation(description: "Insert many documents")
        collection.insertMany([document, document2])
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should insert")
                }
            }, receiveValue: { objectIds in
                XCTAssertEqual(objectIds.count, 2)
                insertManyEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [insertManyEx1], timeout: 4.0)

        let findEx1 = expectation(description: "Find documents")
        collection.find(filter: [:])
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should find")
                }
            }, receiveValue: { findResult in
                XCTAssertEqual(findResult.map({ $0["name"]??.stringValue }), ["fido", "fido", "rex"])
                findEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findEx1], timeout: 4.0)
    }

    func testMongoCollectionFindCombine() {
        var cancellable = Set<AnyCancellable>()
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "tibetan mastiff"]
        let document3: Document = ["name": "rex", "breed": "tibetan mastiff", "coat": ["fawn", "brown", "white"]]
        let findOptions = FindOptions(1, nil, nil)

        let notFoundEx1 = expectation(description: "Find documents")
        collection.find(filter: [:], options: findOptions)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should try to find")
                }
            }, receiveValue: { findResult in
                XCTAssertEqual(findResult.count, 0)
                notFoundEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [notFoundEx1], timeout: 4.0)

        let insEx1 = expectation(description: "Insert document")
        collection.insertMany([document, document2, document3])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in insEx1.fulfill() })
            .store(in: &cancellable)
        wait(for: [insEx1], timeout: 4.0)

        let findEx1 = expectation(description: "Find documents")
        collection.find(filter: [:])
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should find")
                }
            }, receiveValue: { findResult in
                XCTAssertEqual(findResult.map({ $0["name"]??.stringValue }), ["fido", "rex", "rex"])
                findEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findEx1], timeout: 4.0)

        let findEx2 = expectation(description: "Find documents")
        collection.find(filter: [:], options: findOptions)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should find")
                }
            }, receiveValue: { findResult in
                XCTAssertEqual(findResult.count, 1)
                XCTAssertEqual(findResult[0]["name"]??.stringValue, "fido")
                findEx2.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findEx2], timeout: 4.0)

        let findEx3 = expectation(description: "Find documents")
        collection.find(filter: document3, options: findOptions)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should find")
                }
            }, receiveValue: { findResult in
                XCTAssertEqual(findResult.count, 1)
                findEx3.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findEx3], timeout: 4.0)

        let findOneEx1 = expectation(description: "Find one document")
        collection.findOneDocument(filter: document)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should find")
                }
            }, receiveValue: { _ in
                findOneEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findOneEx1], timeout: 4.0)

        let findOneEx2 = expectation(description: "Find one document")
        collection.findOneDocument(filter: document, options: findOptions)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should find")
                }
            }, receiveValue: { _ in
                findOneEx2.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findOneEx2], timeout: 4.0)
    }

    func testMongoCollectionCountAndAggregateCombine() {
        var cancellable = Set<AnyCancellable>()
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        let insEx1 = expectation(description: "Insert document")
        collection.insertMany([document])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in insEx1.fulfill() })
            .store(in: &cancellable)
        wait(for: [insEx1], timeout: 4.0)

        let agrEx1 = expectation(description: "Insert document")
        collection.aggregate(pipeline: [["$match": ["name": "fido"]], ["$group": ["_id": "$name"]]])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in agrEx1.fulfill() })
            .store(in: &cancellable)
        wait(for: [agrEx1], timeout: 4.0)

        let countEx1 = expectation(description: "Count documents")
        collection.count(filter: document)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should count")
                }
            }, receiveValue: { _ in
                countEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [countEx1], timeout: 4.0)

        let countEx2 = expectation(description: "Count documents")
        collection.count(filter: document, limit: 1)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should count")
                }
            }, receiveValue: { count in
                XCTAssertEqual(count, 1)
                countEx2.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [countEx2], timeout: 4.0)
    }

    func testMongoCollectionDeleteOneCombine() {
        var cancellable = Set<AnyCancellable>()
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]

        let deleteEx1 = expectation(description: "Delete 0 documents")
        collection.deleteOneDocument(filter: document)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should count")
                }
            }, receiveValue: { count in
                XCTAssertEqual(count, 0)
                deleteEx1.fulfill()
            })
        .store(in: &cancellable)
        wait(for: [deleteEx1], timeout: 4.0)

        let insEx1 = expectation(description: "Insert document")
        collection.insertMany([document, document2])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in insEx1.fulfill()})
            .store(in: &cancellable)
        wait(for: [insEx1], timeout: 4.0)

        let deleteEx2 = expectation(description: "Delete one document")
        collection.deleteOneDocument(filter: document)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should count")
                }
            }, receiveValue: { count in
                XCTAssertEqual(count, 1)
                deleteEx2.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [deleteEx2], timeout: 4.0)
    }

    func testMongoCollectionDeleteManyCombine() {
        var cancellable = Set<AnyCancellable>()
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]

        let deleteEx1 = expectation(description: "Delete 0 documents")
        collection.deleteManyDocuments(filter: document)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should try to delete")
                }
            }, receiveValue: { count in
                XCTAssertEqual(count, 0)
                deleteEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [deleteEx1], timeout: 4.0)

        let insEx1 = expectation(description: "Insert document")
        collection.insertMany([document, document2])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in insEx1.fulfill() })
            .store(in: &cancellable)
        wait(for: [insEx1], timeout: 4.0)

        let deleteEx2 = expectation(description: "Delete one document")
        collection.deleteManyDocuments(filter: ["breed": "cane corso"])
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should delete")
                }
            }, receiveValue: { count in
                XCTAssertEqual(count, 2)
                deleteEx2.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [deleteEx2], timeout: 4.0)
    }

    func testMongoCollectionUpdateOneCombine() {
        var cancellable = Set<AnyCancellable>()
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        let document5: Document = ["name": "bill", "breed": "great dane"]

        let insEx1 = expectation(description: "Insert document")
        collection.insertMany([document, document2, document3, document4])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in insEx1.fulfill() })
            .store(in: &cancellable)
        wait(for: [insEx1], timeout: 4.0)

        let updateEx1 = expectation(description: "Update one document")
        collection.updateOneDocument(filter: document, update: document2)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should update")
                }
            }, receiveValue: { updateResult in
                XCTAssertEqual(updateResult.matchedCount, 1)
                XCTAssertEqual(updateResult.modifiedCount, 1)
                XCTAssertNil(updateResult.objectId)
                updateEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [updateEx1], timeout: 4.0)

        let updateEx2 = expectation(description: "Update one document")
        collection.updateOneDocument(filter: document5, update: document2, upsert: true)
        .sink(receiveCompletion: { result in
            if case .failure = result {
                XCTFail("Should try to update")
            }
        }, receiveValue: { updateResult in
            XCTAssertEqual(updateResult.matchedCount, 0)
            XCTAssertEqual(updateResult.modifiedCount, 0)
            XCTAssertNotNil(updateResult.objectId)
            updateEx2.fulfill()
        })
        .store(in: &cancellable)
        wait(for: [updateEx2], timeout: 4.0)
    }

    func testMongoCollectionUpdateManyCombine() {
        var cancellable = Set<AnyCancellable>()
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]
        let document4: Document = ["name": "ted", "breed": "bullmastiff"]
        let document5: Document = ["name": "bill", "breed": "great dane"]

        let insEx1 = expectation(description: "Insert document")
        collection.insertMany([document, document2, document3, document4])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                insEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [insEx1], timeout: 4.0)

        let updateEx1 = expectation(description: "Update one document")
        collection.updateManyDocuments(filter: document, update: document2)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should update")
                }
            }, receiveValue: { updateResult in
                XCTAssertEqual(updateResult.matchedCount, 1)
                XCTAssertEqual(updateResult.modifiedCount, 1)
                XCTAssertNil(updateResult.objectId)
                updateEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [updateEx1], timeout: 4.0)

        let updateEx2 = expectation(description: "Update one document")
        collection.updateManyDocuments(filter: document5, update: document2, upsert: true)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should try to update")
                }
            }, receiveValue: { updateResult in
                XCTAssertEqual(updateResult.matchedCount, 0)
                XCTAssertEqual(updateResult.modifiedCount, 0)
                XCTAssertNotNil(updateResult.objectId)
                updateEx2.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [updateEx2], timeout: 4.0)
    }

    func testMongoCollectionFindAndUpdateCombine() {
        var cancellable = Set<AnyCancellable>()
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]

        let findOneUpdateEx1 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document, update: document2)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should try to update")
                }
            }, receiveValue: { updateResult in
                XCTAssertNil(updateResult)
                findOneUpdateEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findOneUpdateEx1], timeout: 4.0)

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneUpdateEx2 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document2, update: document3, options: options1)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should update")
                }
            }, receiveValue: { updateResult in
                guard let updateResult = updateResult else {
                    XCTFail("Should find")
                    return
                }
                XCTAssertEqual(updateResult["name"]??.stringValue, "john")
                findOneUpdateEx2.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findOneUpdateEx2], timeout: 4.0)

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneUpdateEx3 = expectation(description: "Find one document and update")
        collection.findOneAndUpdate(filter: document, update: document2, options: options2)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should update")
                }
            }, receiveValue: { updateResult in
                guard let updateResult = updateResult else {
                    XCTFail("Should find")
                    return
                }
                XCTAssertEqual(updateResult["name"]??.stringValue, "rex")
                findOneUpdateEx3.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findOneUpdateEx3], timeout: 4.0)
    }

    func testMongoCollectionFindAndReplaceCombine() {
        var cancellable = Set<AnyCancellable>()
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]
        let document2: Document = ["name": "rex", "breed": "cane corso"]
        let document3: Document = ["name": "john", "breed": "cane corso"]

        let findOneReplaceEx1 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document, replacement: document2)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should try to replace")
                }
            }, receiveValue: { updateResult in
                XCTAssertNil(updateResult)
                findOneReplaceEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findOneReplaceEx1], timeout: 4.0)

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, true)
        let findOneReplaceEx2 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document2, replacement: document3, options: options1)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should replace")
                }
            }, receiveValue: { updateResult in
                guard let updateResult = updateResult else {
                    XCTFail("Should find")
                    return
                }
                XCTAssertEqual(updateResult["name"]??.stringValue, "john")
                findOneReplaceEx2.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findOneReplaceEx2], timeout: 4.0)

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1], true, false)
        let findOneReplaceEx3 = expectation(description: "Find one document and replace")
        collection.findOneAndReplace(filter: document, replacement: document2, options: options2)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should try to replace")
                }
            }, receiveValue: { updateResult in
                XCTAssertNil(updateResult)
                findOneReplaceEx3.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findOneReplaceEx3], timeout: 4.0)
    }

    func testMongoCollectionFindAndDeleteCombine() {
        var cancellable = Set<AnyCancellable>()
        let collection = setupMongoCollection()
        let document: Document = ["name": "fido", "breed": "cane corso"]

        let insEx1 = expectation(description: "Insert document")
        collection.insertMany([document])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in insEx1.fulfill() })
            .store(in: &cancellable)
        wait(for: [insEx1], timeout: 4.0)

        let findOneDeleteEx1 = expectation(description: "Find one document and delete")
        collection.findOneAndDelete(filter: document)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should try to delete")
                }
            }, receiveValue: { updateResult in
                XCTAssertNotNil(updateResult)
                findOneDeleteEx1.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findOneDeleteEx1], timeout: 4.0)

        let options1 = FindOneAndModifyOptions(["name": 1], ["_id": 1], false, false)
        let findOneDeleteEx2 = expectation(description: "Find one document and delete")
        collection.findOneAndDelete(filter: document, options: options1)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result,
                    error.localizedDescription == "expected pre-image to match projection matcher" {
                    // FIXME: It seems there is a possible server bug that does not handle
                    // `projection` in `FindOneAndModifyOptions` correctly. The returned error is:
                    // "expected pre-image to match projection matcher"
                    // https://jira.mongodb.org/browse/REALMC-6878
                    findOneDeleteEx2.fulfill()
                } else {
                    XCTFail("Please review test cases for findOneAndDelete.")
                }
            }, receiveValue: { _ in
                XCTFail("Please review test cases for findOneAndDelete.")
            })
//            .sink(receiveCompletion: { result in
//                if case .failure(let error) = result {
//                    XCTFail("Should try to find instead of \(error)")
//                }
//            }, receiveValue: { deleteResult in
//                XCTAssertNil(deleteResult)
//                findOneDeleteEx2.fulfill()
//            })
        .store(in: &cancellable)
        wait(for: [findOneDeleteEx2], timeout: 4.0)

        let options2 = FindOneAndModifyOptions(["name": 1], ["_id": 1])
        let findOneDeleteEx3 = expectation(description: "Find one document and delete")
        collection.findOneAndDelete(filter: document, options: options2)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result,
                    error.localizedDescription == "expected pre-image to match projection matcher" {
                    // FIXME: It seems there is a possible server bug that does not handle
                    // `projection` in `FindOneAndModifyOptions` correctly. The returned error is:
                    // "expected pre-image to match projection matcher"
                    // https://jira.mongodb.org/browse/REALMC-6878
                    findOneDeleteEx3.fulfill()
                } else {
                    XCTFail("Please review test cases for findOneAndDelete.")
                }
            }, receiveValue: { _ in
                XCTFail("Please review test cases for findOneAndDelete.")
            })
//            .sink(receiveCompletion: { result in
//                if case .failure(let error) = result {
//                    XCTFail("Should try to find instead of \(error)")
//                }
//            }, receiveValue: { deleteResult in
//                guard let deleteResult = deleteResult else {
//                    XCTFail("Should delete")
//                    return
//                }
//                XCTAssertEqual(deleteResult["name"] as! String, "fido")
//                findOneDeleteEx3.fulfill()
//            })
            .store(in: &cancellable)
        wait(for: [findOneDeleteEx3], timeout: 4.0)

        let findEx = expectation(description: "Find documents")
        collection.find(filter: [:])
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should try to update")
                }
            }, receiveValue: { updateResult in
                XCTAssertEqual(updateResult.count, 0)
                findEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [findEx], timeout: 4.0)
    }

    func testCallFunctionCombine() {
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)
        var cancellable = Set<AnyCancellable>()

        let regEx = expectation(description: "Should register")
        app.emailPasswordAuth.registerUser(email: email, password: password)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should register")
                }
            }, receiveValue: { _ in
                regEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [regEx], timeout: 4.0)

        let credentials = Credentials.emailPassword(email: email, password: password)
        var syncUser: User!
        let loginEx = expectation(description: "Should login")
        app.login(credentials: credentials)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should login")
                }
            }, receiveValue: { user in
                syncUser = user
                loginEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [loginEx], timeout: 4.0)

        let sumEx = expectation(description: "Should calc sum")
        syncUser.functions.sum([1, 2, 3, 4, 5])
            .sink(receiveCompletion: { (result) in
                if case .failure = result {
                    XCTFail("Should calc sum 15")
                }
            }, receiveValue: { bson in
                guard case let .int64(sum) = bson else {
                    XCTFail("Should be int64")
                    return
                }
                XCTAssertEqual(sum, 15)
                sumEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [sumEx], timeout: 4.0)

        let userDataEx = expectation(description: "Should update user data")
        syncUser.functions.updateUserData([["favourite_colour": "green", "apples": 10]])
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    XCTFail("Should update user data")
                }
            }, receiveValue: { bson in
                guard case let .bool(upd) = bson else {
                    XCTFail("Should be bool")
                    return
                }
                XCTAssertTrue(upd)
                userDataEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [userDataEx], timeout: 4.0)

    }

    func testAPIKeyAuthCombine() {
        var cancellable = Set<AnyCancellable>()
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")
        app.emailPasswordAuth.registerUser(email: email, password: password)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in registerUserEx.fulfill() })
            .store(in: &cancellable)
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        var syncUser: User?
        app.login(credentials: Credentials.emailPassword(email: email, password: password))
            .sink(receiveCompletion: { _ in },
                  receiveValue: { (user) in
                syncUser = user
                loginEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [loginEx], timeout: 4.0)

        let createAPIKeyEx = expectation(description: "Create user api key")
        var apiKey: UserAPIKey?
        syncUser?.apiKeysAuth.createAPIKey(named: "my-api-key")
            .sink(receiveCompletion: { (result) in
                if case .failure = result {
                    XCTFail("Should create user api key")
                }
            }, receiveValue: { (userApiKey) in
                apiKey = userApiKey
                createAPIKeyEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [createAPIKeyEx], timeout: 4.0)

        let fetchAPIKeyEx = expectation(description: "Fetch user api key")
        var objId: ObjectId? = try? ObjectId(string: apiKey!.objectId.stringValue)
        syncUser?.apiKeysAuth.fetchAPIKey(objId!)
            .sink(receiveCompletion: { (result) in
                if case .failure = result {
                    XCTFail("Should fetch user api key")
                }
            }, receiveValue: { (userApiKey) in
                apiKey = userApiKey
                fetchAPIKeyEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [fetchAPIKeyEx], timeout: 4.0)

        let fetchAPIKeysEx = expectation(description: "Fetch user api keys")
        syncUser?.apiKeysAuth.fetchAPIKeys()
            .sink(receiveCompletion: { (result) in
                if case .failure = result {
                    XCTFail("Should fetch user api keys")
                }
            }, receiveValue: { (userApiKeys) in
                XCTAssertEqual(userApiKeys.count, 1)
                fetchAPIKeysEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [fetchAPIKeysEx], timeout: 4.0)

        let disableKeyEx = expectation(description: "Disable API key")
        objId = try? ObjectId(string: apiKey!.objectId.stringValue)
        syncUser?.apiKeysAuth.disableAPIKey(objId!)
            .sink(receiveCompletion: { (result) in
                if case .failure = result {
                    XCTFail("Should disable user api key")
                }
            }, receiveValue: { _ in
                disableKeyEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [disableKeyEx], timeout: 4.0)

        let enableKeyEx = expectation(description: "Enable API key")
        syncUser?.apiKeysAuth.enableAPIKey(objId!)
            .sink(receiveCompletion: { (result) in
                if case .failure = result {
                    XCTFail("Should enable user api key")
                }
            }, receiveValue: { _ in
                enableKeyEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [enableKeyEx], timeout: 4.0)

        let deleteKeyEx = expectation(description: "Delete API key")
        syncUser?.apiKeysAuth.deleteAPIKey(objId!)
            .sink(receiveCompletion: { (result) in
                if case .failure = result {
                    XCTFail("Should delete user api key")
                }
            }, receiveValue: { _ in
                deleteKeyEx.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [deleteKeyEx], timeout: 4.0)
    }

    func testPushRegistrationCombine() {
        var cancellable = Set<AnyCancellable>()
        let email = "realm_tests_do_autoverify\(randomString(7))@\(randomString(7)).com"
        let password = randomString(10)

        let registerUserEx = expectation(description: "Register user")
        app.emailPasswordAuth.registerUser(email: email, password: password)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in registerUserEx.fulfill() })
            .store(in: &cancellable)
        wait(for: [registerUserEx], timeout: 4.0)

        let loginEx = expectation(description: "Login user")
        app.login(credentials: Credentials.emailPassword(email: email, password: password))
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in loginEx.fulfill() })
            .store(in: &cancellable)
        wait(for: [loginEx], timeout: 4.0)

        let registerDeviceExpectation = expectation(description: "Register Device")
        let client = app.pushClient(serviceName: "gcm")
        client.registerDevice(token: "some-token", user: app.currentUser!)
            .sink(receiveCompletion: { (result) in
                if case .failure = result {
                    XCTFail("Should register device")
                }
            }, receiveValue: { _ in
                registerDeviceExpectation.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [registerDeviceExpectation], timeout: 4.0)

        let dergisterDeviceExpectation = expectation(description: "Deregister Device")
        client.deregisterDevice(user: app.currentUser!)
            .sink(receiveCompletion: { (result) in
                if case .failure = result {
                    XCTFail("Should deregister device")
                }
            }, receiveValue: { _ in
                dergisterDeviceExpectation.fulfill()
            })
            .store(in: &cancellable)
        wait(for: [dergisterDeviceExpectation], timeout: 4.0)
    }
}
