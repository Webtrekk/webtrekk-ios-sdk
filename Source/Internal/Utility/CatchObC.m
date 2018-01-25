//
//  CatchObC.m
//  Pods
//
//  Created by arsen.vartbaronov on 12.04.17.
//
//

#import "CatchObC.h"

@implementation CatchObC

+ (BOOL)catchException:(void(^)(void))tryBlock error:(__autoreleasing NSError **)error {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        NSMutableDictionary * userInfo = [NSMutableDictionary dictionaryWithDictionary:exception.userInfo];
        [userInfo setValue:exception.reason forKey:NSLocalizedDescriptionKey];
        
        *error = [[NSError alloc] initWithDomain:exception.name
                                            code:0
                                        userInfo: userInfo];
        return NO;
    }
}

@end
