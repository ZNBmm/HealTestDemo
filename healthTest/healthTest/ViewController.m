//
//  ViewController.m
//  healthTest
//
//  Created by mac on 2017/4/10.
//  Copyright © 2017年 mac. All rights reserved.
//

#import "ViewController.h"
#import <HealthKit/HealthKit.h>
#define distanceRecorded 1000
@interface ViewController ()<UITextFieldDelegate>
@property (strong, nonatomic) NSDate *startDate;
@property (weak, nonatomic) IBOutlet UILabel *startTime;
@property (weak, nonatomic) IBOutlet UILabel *endTime;
@property (weak, nonatomic) IBOutlet UITextField *textF;

@property (weak, nonatomic) IBOutlet UILabel *stepCount;
@property (strong, nonatomic) HKHealthStore *healthKitStore;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _textF.delegate = self;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";

    self.startDate = [NSDate date];
    self.startTime.text = [fmt stringFromDate:[NSDate date]];
    
    // 1创建 healthKitStore 对象
    self.healthKitStore = [[HKHealthStore alloc] init];
    
    // 2 创建 基于HKSampleType的健康对像
    // 2.1创建 height 类型
    HKSampleType *height = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    NSSet *healthDataToRead = [NSSet setWithArray:@[height]];
    HKSampleType *runing = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    NSSet *healthDataToWrite = [NSSet setWithArray:@[runing]];
    
    // 3请求授权
    // 3.1第一个参数可写
    // 3.2第二个参数可读
    // 3.3第三个参数授权回调
    [_healthKitStore requestAuthorizationToShareTypes:healthDataToWrite readTypes:healthDataToRead completion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            NSLog(@"授权成功");
            [self reloadData];
        }
    }];
    
  
    
}

- (void)reloadData {
    
    HKQuantityType *stepType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    [self fetchSumOfSamplesTodayForType:stepType unit:[HKUnit countUnit] completion:^(double stepCount, NSError *error) {
        NSLog(@"%f",stepCount);
        dispatch_async(dispatch_get_main_queue(), ^{
            _stepCount.text = [NSString stringWithFormat:@"%.f",stepCount];
        });
    }];
}
#pragma mark - #pragma mark - Reading HealthKit Data

- (void)fetchSumOfSamplesTodayForType:(HKQuantityType *)quantityType unit:(HKUnit *)unit completion:(void (^)(double, NSError *))completionHandler {
    NSPredicate *predicate = [self predicateForSamplesToday];
    
    HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:quantityType quantitySamplePredicate:predicate options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery *query, HKStatistics *result, NSError *error) {
        HKQuantity *sum = [result sumQuantity];
        
        if (completionHandler) {
            double value = [sum doubleValueForUnit:unit];
            
            completionHandler(value, error);
        }
    }];
    
    [self.healthKitStore executeQuery:query];
}
- (NSPredicate *)predicateForSamplesToday {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDate *now = [NSDate date];
    
    NSDate *startDate = [calendar startOfDayForDate:now];
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    return [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
}
- (IBAction)writeStepcount:(UIButton *)sender {
     [self addstepWithStepNum:_textF.text.doubleValue];
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {

    [self.view endEditing:YES];
}

- (void)addstepWithStepNum:(double)stepNum {
    
    HKQuantitySample *stepCorrelationItem = [self stepCorrelationWithStepNum:stepNum];
    
    [self.healthKitStore saveObject:stepCorrelationItem withCompletion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self.view endEditing:YES];
                UIAlertView *doneAlertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"添加成功" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                [doneAlertView show];
                
                [self reloadData];
                
            }
            else {
                NSLog(@"The error was: %@.", error);
                UIAlertView *doneAlertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"添加失败" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                [doneAlertView show];
                return ;
            }
        });
    }];
}
- (HKQuantitySample *)stepCorrelationWithStepNum:(double)stepNum {
    NSDate *endDate = [NSDate date];
    NSDate *startDate = [NSDate dateWithTimeInterval:-300 sinceDate:endDate];
    
    HKQuantity *stepQuantityConsumed = [HKQuantity quantityWithUnit:[HKUnit countUnit] doubleValue:stepNum];
    
    HKQuantityType *stepConsumedType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    UIDevice *dev = [UIDevice currentDevice];

    HKDevice *device = [[HKDevice alloc] initWithName:dev.name manufacturer:@"Apple" model:dev.model hardwareVersion:@"iPhone9,1" firmwareVersion:@"9.2" softwareVersion:@"10.2" localIdentifier:@"default" UDIDeviceIdentifier:dev.identifierForVendor.UUIDString];

    HKQuantitySample *stepConsumedSample = [HKQuantitySample quantitySampleWithType:stepConsumedType quantity:stepQuantityConsumed startDate:startDate endDate:endDate device:device metadata:nil];
    return stepConsumedSample;
}

@end
