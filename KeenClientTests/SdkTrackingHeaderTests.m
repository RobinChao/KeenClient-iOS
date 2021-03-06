//
//  SdkTrackingHeaderTests.m
//  KeenClient
//
//  Created by Brian Baumhover on 5/9/17.
//  Copyright © 2017 Keen Labs. All rights reserved.
//

#import <OCMock/OCMock.h>

#import "KeenClient.h"
#import "KeenConstants.h"
#import "HTTPCodes.h"

#import "KeenClientTestable.h"
#import "KeenTestConstants.h"

#import "SdkTrackingHeaderTests.h"

@implementation SdkTrackingHeaderTests

- (void)validateSdkVersionHeaderFieldForRequest:(id)requestObject {
    XCTAssertTrue([requestObject isKindOfClass:[NSMutableURLRequest class]]);
    NSMutableURLRequest *request = requestObject;
    NSString *versionInfo = [request valueForHTTPHeaderField:kKeenSdkVersionHeader];
    XCTAssertNotNil(versionInfo, @"Request should have included SDK info header.");
    NSRange platformRange = [versionInfo rangeOfString:@"ios-"];
    XCTAssertEqual(platformRange.location, 0, @"SDK info header should start with the platform.");
    XCTAssertEqual(platformRange.length, 4, @"Unexpected SDK platform info.");
    NSRange versionRange = [versionInfo rangeOfString:kKeenSdkVersion];
    XCTAssertEqual(versionRange.location, 4, @"SDK version should be included in SDK platform info.");
}

- (void)testSdkTrackingHeadersOnUpload {
    XCTestExpectation *requestValidated = [self expectationWithDescription:@"request was validated"];
    // mock an empty response from the server
    KeenClient *client = [self createClientWithRequestValidator:^BOOL(id obj) {
        [self validateSdkVersionHeaderFieldForRequest:obj];
        [requestValidated fulfill];
        return @YES;
    }];

    // add an event
    [client addEvent:[NSDictionary dictionaryWithObject:@"apple" forKey:@"a"] toEventCollection:@"foo" error:nil];

    XCTestExpectation *responseArrived = [self expectationWithDescription:@"response of async request has arrived"];
    // and "upload" it
    [client uploadWithFinishedBlock:^{
        [responseArrived fulfill];
    }];

    [self waitForExpectationsWithTimeout:kTestExpectationTimeoutInterval
                                 handler:^(NSError *_Nullable error) {
                                     XCTAssertNil(error, @"Test should complete within expected interval.");
                                 }];
}

- (void)testSdkTrackingHeadersOnQuery {
    XCTestExpectation *requestValidated = [self expectationWithDescription:@"request was validated"];
    KeenClient *client = [self createClientWithResponseData:@{
        @"result": @10
    }
        andStatusCode:HTTPCode200OK
        andNetworkConnected:@YES
        andRequestValidator:^BOOL(id obj) {
            [self validateSdkVersionHeaderFieldForRequest:obj];
            [requestValidated fulfill];
            return @YES;
        }];

    KIOQuery *query =
        [[KIOQuery alloc] initWithQuery:@"count" andPropertiesDictionary:@{
            @"event_collection": @"event_collection"
        }];

    XCTestExpectation *responseArrived = [self expectationWithDescription:@"response of async request has arrived"];
    [client runAsyncQuery:query
        completionHandler:^(NSData *queryResponseData, NSURLResponse *response, NSError *error) {
            [responseArrived fulfill];
        }];

    [self waitForExpectationsWithTimeout:kTestExpectationTimeoutInterval
                                 handler:^(NSError *_Nullable error) {
                                     XCTAssertNil(error, @"Test should complete within expected interval.");
                                 }];
}

- (void)testSdkTrackingHeadersOnMultiAnalysis {
    XCTestExpectation *requestValidated = [self expectationWithDescription:@"request was validated"];
    KeenClient *client = [self createClientWithResponseData:@{
        @"result": @{@"query1": @10, @"query2": @1}
    }
        andStatusCode:HTTPCode200OK
        andNetworkConnected:@YES
        andRequestValidator:^BOOL(id obj) {
            [self validateSdkVersionHeaderFieldForRequest:obj];
            [requestValidated fulfill];
            return @YES;
        }];

    KIOQuery *countQuery =
        [[KIOQuery alloc] initWithQuery:@"count" andPropertiesDictionary:@{
            @"event_collection": @"event_collection"
        }];

    KIOQuery *averageQuery = [[KIOQuery alloc] initWithQuery:@"count_unique"
                                     andPropertiesDictionary:@{
                                         @"event_collection": @"event_collection",
                                         @"target_property": @"something"
                                     }];

    XCTestExpectation *responseArrived = [self expectationWithDescription:@"response of async request has arrived"];
    [client runAsyncMultiAnalysisWithQueries:@[countQuery, averageQuery]
                           completionHandler:^(NSData *queryResponseData, NSURLResponse *response, NSError *error) {
                               [responseArrived fulfill];
                           }];

    [self waitForExpectationsWithTimeout:kTestExpectationTimeoutInterval
                                 handler:^(NSError *_Nullable error) {
                                     XCTAssertNil(error, @"Test should complete within expected interval.");
                                 }];
}

@end
