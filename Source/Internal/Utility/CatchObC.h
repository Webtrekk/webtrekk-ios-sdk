//
//  CatchObC.h
//  Pods
//
//  Created by arsen.vartbaronov on 12.04.17.
//
//

#ifndef CatchObC_h
#define CatchObC_h

#import <Foundation/Foundation.h>

@interface CatchObC : NSObject
    
+ (BOOL)catchException:(void(^)(void))tryBlock error:(__autoreleasing NSError **)error;
    
@end

#endif /* CatchObC_h */
