//
//  CatchObC.h
//  Pods
//
//  Created by arsen.vartbaronov on 12.04.17.
//
//

#import <Foundation/Foundation.h>

@interface CatchObC : NSObject
    
+ (BOOL)catchException:(void(^)(void))tryBlock error:(__autoreleasing NSError **)error;
    
@end
