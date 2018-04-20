//
//  XLLBaseSoapEngine.h
//  XLLSoapRequest
//
//  Created by 肖乐 on 2018/4/20.
//  Copyright © 2018年 iOSCoder. All rights reserved.
//  soap请求基类

#import <Foundation/Foundation.h>

@interface XLLBaseSoapEngine : NSObject

/**
 POST请求
 参数都在固定的input节点下

 @param methodName 方法名
 @param params 参数字典
 @param success 成功回执
 @param failure 失败回执
 */
+ (void)POSTInput:(NSString *)methodName
           params:(NSDictionary *)params
          success:(void(^)(id dataObject))success
          failure:(void(^)(NSError *error))failure;


/**
 POST
 每个参数key单独作为节点

 @param methodName 方法名
 @param params 参数字典
 @param success 成功回执
 @param failure 失败回执
 */
+ (void)POSTNoInput:(NSString *)methodName
             params:(NSDictionary *)params
            success:(void(^)(id dataObject))success
            failure:(void(^)(NSError *error))failure;

@end
