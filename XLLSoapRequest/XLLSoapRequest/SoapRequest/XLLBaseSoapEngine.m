//
//  XLLBaseSoapEngine.m
//  XLLSoapRequest
//
//  Created by 肖乐 on 2018/4/20.
//  Copyright © 2018年 iOSCoder. All rights reserved.
//

#import "XLLBaseSoapEngine.h"
#import <pthread.h>

//虚拟的域名地址
#define netWorkServiceAddress  @"http://xiaolele.org"
//虚拟的soapAction
#define defaultSOAPActionStr @"http://xiaolele.org/IAppWebService2/"

@implementation XLLBaseSoapEngine
static pthread_mutex_t pthread_;
static BOOL isInitPthread_;

#pragma mark - 静态变量初始化
/**
+ (void)initialize
{
    pthread_mutex_init(&phread_, NULL);
}
 */
+ (pthread_mutex_t)pthread_
{
    if (isInitPthread_ == NO)
    {
        isInitPthread_ = YES;
        pthread_mutex_init(&pthread_, NULL);
    }
    return pthread_;
}


/**
 请求体拼接基本方法
 其中的%@即存放参数元素的位置。这里要根据后台文档的要求进行书写
 
 @return 完整请求体
 */
+ (NSString *)defaultSoapMessage
{
    NSString *soapBody=@"<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:tem=\"http://tempuri.org/\">""<soapenv:Body>%@</soapenv:Body></soapenv:Envelope>";
    return soapBody;
}


/**
 基本参数
 根据后台要求的形式与内容拼接

 @return 基本参数xml
 */
+ (NSString *)baseParams
{
    NSMutableString *soap = [NSMutableString string];
    //基本参数1 API_ID
    [soap appendFormat:@"<tem:API_ID>API_ID</tem:API_ID>"];
    //基本参数2 API_KEY
    [soap appendFormat:@"<tem:API_KEY>API_KEY</tem:API_KEY>"];
    return soap;
}


/**
 添加参数
 有的方法会专门有一个固定的参数作为元素节点。有的是参数名分别作为一个节点
 此方法形式为有一个固定input节点，input节点内容为参数的json

 @param params 参数 可能是字典，可能是数组
 @param methodName 方法名
 @return 请求体
 */
+ (NSString *)nameSpaceInputSoapMessage:(NSDictionary *)params methodName:(NSString *)methodName
{
    // 将参数转为json
    NSString *jsonStr = [self convertJsonStrWithDic:params];
    NSMutableString *soap = [NSMutableString stringWithFormat:@"<tem:%@>", methodName];
    // 拼接基本参数
    [soap appendString:[self baseParams]];
    // 拼接传入的参数
    [soap appendFormat:@"<tem:input>%@</tem:input>", jsonStr];
    [soap appendFormat:@"</tem:%@>", methodName];
    return [NSString stringWithFormat:[self defaultSoapMessage], soap];
}

/**
 添加参数
 有的方法会专门有一个固定的参数作为元素节点。有的是参数名分别作为一个节点
 此方法形式为参数名单独作为一个节点
 
 @param params 参数 可能是字典，可能是数组
 @param methodName 方法名
 @return 请求体
 */
+ (NSString *)nameSpaceNoInputSoapMessage:(NSDictionary *)params methodName:(NSString *)methodName
{
    NSMutableString *soap = [NSMutableString stringWithFormat:@"<tem:%@>", methodName];
    // 拼接基本参数
    [soap appendString:[self baseParams]];
    for (NSString *key in params) {
        [soap appendFormat:@"<tem:%@>%@</tem:%@>", key, params[key], key];
    }
    [soap appendFormat:@"</tem:%@>", methodName];
    return [NSString stringWithFormat:[self defaultSoapMessage], soap];
}

/**
 字典转json

 @param params 参数字典
 @return json
 */
+ (NSString *)convertJsonStrWithDic:(NSDictionary *)params
{
    NSDate *currentDate = [NSDate date];//获取当前时间，日期
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"YYYY-M-dd HH:mm:SS"];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    
    NSMutableDictionary *jsonDict = [NSMutableDictionary dictionary];
    [jsonDict setValue:@"" forKey:@"message"];
    [jsonDict setValue:@"" forKey:@"status"];
    [jsonDict setValue:params forKey:@"data"];
    [jsonDict setValue:dateString forKey:@"current_datetime"];
    
    NSError *error;
    NSString *jsonStr = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingPrettyPrinted error:&error];
    
    if (jsonData) {
        jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonStr;
}

// input节点 Post请求
+ (void)POSTInput:(NSString *)methodName params:(NSDictionary *)params success:(void (^)(id))success failure:(void (^)(NSError *))failure
{
    [self BasePOST:methodName isInput:YES params:params success:success failure:failure];
}

// 非input节点 Post请求
+ (void)POSTNoInput:(NSString *)methodName params:(NSDictionary *)params success:(void (^)(id))success failure:(void (^)(NSError *))failure
{
    [self BasePOST:methodName isInput:NO params:params success:success failure:failure];
}

+ (void)BasePOST:(NSString *)methodName isInput:(BOOL)isInput params:(NSDictionary *)params success:(void(^)(id))success failure:(void (^)(NSError *))failure
{
    //打印日志
    [self printLogWithParam:params methodName:methodName];
    NSString *soapMessage = nil;
    if (isInput) {
        soapMessage = [self nameSpaceInputSoapMessage:params methodName:methodName];
    } else {
        soapMessage = [self nameSpaceNoInputSoapMessage:params methodName:methodName];
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:netWorkServiceAddress]];
    NSString *msgLength = [NSString stringWithFormat:@"%lu", (unsigned long)[soapMessage length]];
    [request addValue: @"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request addValue: msgLength forHTTPHeaderField:@"Content-Length"];
    [request addValue:[NSString stringWithFormat:@"%@%@", defaultSOAPActionStr, methodName] forHTTPHeaderField:@"SOAPAction"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody: [soapMessage dataUsingEncoding:NSUTF8StringEncoding]];
    
    pthread_mutex_t pthread = [self pthread_];
    pthread_mutex_lock(&pthread);
    NSDictionary *object = @{
                             @"request":request,
                             @"success":success,
                             @"failure":failure
                             };
    [self performSelector:@selector(startRequest:) onThread:[self networkRequestThread] withObject:object waitUntilDone:NO modes:[[NSSet setWithObject:NSRunLoopCommonModes] allObjects]];
    pthread_mutex_unlock(&pthread);
}

// 开始请求
+ (void)startRequest:(NSDictionary *)object
{
    NSURLRequest *request = object[@"request"];
    void(^success)(id) = object[@"success"];
    void(^failure)(NSError *) = object[@"failure"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
#pragma clang diagnostic pop
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
#if DEBUG
            NSLog(@"\n\n urlString : %@ \n%@\n\n", request.URL, string);
#endif

            if (connectionError || !response)
            {
                if (failure) {
                    failure(connectionError);
                }
                return ;
            }
            if (data) {
                
                //进行xml解析
                if (success) {
                    success(data);
                }
            }
        });
    }];
}

// 单独开辟的请求线程
+ (NSThread *)networkRequestThread
{
    static NSThread *_networkRequestThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _networkRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [_networkRequestThread start];
    });
    return _networkRequestThread;
}

// 添加runloop保活
+ (void)networkRequestThreadEntryPoint:(id)__unused object
{
    @autoreleasepool {
        [[NSThread currentThread] setName:@"XLLBaseSoapEngine"];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

/**
 日志打印

 @param nParemeters 参数
 @param methodName 方法名
 */
+ (void)printLogWithParam:(NSDictionary *)nParemeters methodName:(NSString *)methodName
{
#if DEBUG
    // 便于调试查看请求体
    NSLog(@"请求的方法名为 : %@\n", methodName);
    NSLog(@"\n\n 最终的请求参数列表 : %@\n", nParemeters);
#endif
}


@end
