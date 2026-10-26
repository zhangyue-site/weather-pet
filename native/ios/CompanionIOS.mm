// SPDX-License-Identifier: MIT
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/os/mutex.h"

// Keep the native queue independent of Godot's Variant allocator and thread.
@interface CourtyardLocation : NSObject <CLLocationManagerDelegate>
@property(nonatomic, strong) CLLocationManager *manager;
@property(nonatomic, strong) CLGeocoder *geocoder;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *events;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) int64_t requestID;
@property(nonatomic) BOOL waiting;
@property(nonatomic) BOOL locating;
@property(nonatomic) BOOL geocoding;
@property(nonatomic) BOOL powerSaving;
@property(nonatomic) BOOL reduceMotion;
- (void)request:(int64_t)requestID;
- (void)cancel;
- (NSArray<NSDictionary *> *)drain;
@end

@implementation CourtyardLocation
- (instancetype)init {
    if ((self = [super init])) {
        _events = [NSMutableArray array];
        _geocoder = [CLGeocoder new];
        _powerSaving = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshPower)
            name:NSProcessInfoPowerStateDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshPower)
            name:UIDeviceBatteryLevelDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshPower)
            name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pause)
            name:UIApplicationDidEnterBackgroundNotification object:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
            [self refreshPower];
        });
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)refreshPower {
    float level = UIDevice.currentDevice.batteryLevel;
    @synchronized(self) {
        self.powerSaving = NSProcessInfo.processInfo.lowPowerModeEnabled || (level >= 0 && level <= .2);
        self.reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    }
}
- (void)pause { [self cancel]; }
- (void)push:(NSDictionary *)event {
    NSMutableDictionary *tagged = [event mutableCopy];
    tagged[@"request_id"] = @(self.requestID);
    @synchronized(self) { [self.events addObject:tagged]; }
}
- (NSArray<NSDictionary *> *)drain {
    @synchronized(self) { NSArray *result = [self.events copy]; [self.events removeAllObjects]; return result; }
}
- (void)cancel {
    NSAssert(NSThread.isMainThread, @"CoreLocation must run on main thread");
    self.generation += 1;
    self.waiting = self.locating = self.geocoding = NO;
    [self.manager stopUpdatingLocation];
    self.manager.delegate = nil;
    self.manager = nil;
    [self.geocoder cancelGeocode];
    @synchronized(self) { [self.events removeAllObjects]; }
}
- (void)fail:(NSString *)message {
    self.waiting = self.locating = NO;
    [self.manager stopUpdatingLocation];
    self.manager.delegate = nil;
    [self push:@{@"type":@"error", @"message":message}];
}
- (void)request:(int64_t)requestID {
    [self cancel];
    self.requestID = requestID;
    if (![CLLocationManager locationServicesEnabled]) { [self fail:@"系统定位已关闭 · 可在设置中选择城市"]; return; }
    self.manager = [CLLocationManager new];
    self.manager.delegate = self;
    self.manager.desiredAccuracy = kCLLocationAccuracyKilometer;
    self.waiting = YES;
    NSUInteger token = self.generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 45 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (token == self.generation && self.waiting) [self fail:@"定位超时 · 可在设置中选择城市"];
    });
    [self startIfAuthorized];
}
- (void)startIfAuthorized {
    if (!self.waiting || self.locating) return;
    CLAuthorizationStatus status = self.manager.authorizationStatus;
    if (status == kCLAuthorizationStatusNotDetermined) { [self.manager requestWhenInUseAuthorization]; return; }
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        [self fail:@"未获定位权限 · 可在设置中选择城市"]; return;
    }
    self.locating = YES;
    [self.manager requestLocation];
}
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (manager == self.manager) [self startIfAuthorized];
}
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (manager != self.manager || !self.waiting) return;
    if (error.code == kCLErrorLocationUnknown) return; // The bounded request may still recover.
    [self fail:error.code == kCLErrorDenied ? @"未获定位权限 · 可手动选择城市" : @"暂未获取位置 · 可手动选择城市"];
}
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (manager != self.manager || !self.waiting) return;
    CLLocation *location = locations.lastObject;
    if (!location || location.horizontalAccuracy < 0 || fabs(location.timestamp.timeIntervalSinceNow) > 300
        || !CLLocationCoordinate2DIsValid(location.coordinate)) return;
    self.waiting = self.locating = NO;
    [manager stopUpdatingLocation];
    manager.delegate = nil;
    [self push:@{@"type":@"location", @"lat":@(location.coordinate.latitude), @"lon":@(location.coordinate.longitude)}];
    self.geocoding = YES;
    NSUInteger token = self.generation;
    [self.geocoder reverseGeocodeLocation:location preferredLocale:[NSLocale localeWithLocaleIdentifier:@"zh_CN"]
        completionHandler:^(NSArray<CLPlacemark *> *places, NSError *error) {
        if (token != self.generation || !self.geocoding) return;
        self.geocoding = NO;
        CLPlacemark *place = places.firstObject;
        NSString *city = place.locality ?: place.administrativeArea ?: @"";
        NSString *district = place.subLocality ?: @"";
        NSString *name = city;
        if (district.length && ![district isEqualToString:city]) name = city.length ? [city stringByAppendingFormat:@" · %@", district] : district;
        [self push:@{@"type":@"name", @"name":name}];
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (token != self.generation || !self.geocoding) return;
        self.geocoding = NO;
        [self.geocoder cancelGeocode];
        [self push:@{@"type":@"name", @"name":@""}];
    });
}
@end

class CompanionIOS : public Object {
    GDCLASS(CompanionIOS, Object);
    CourtyardLocation *__strong service;
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("request_location", "request_id"), &CompanionIOS::request_location);
        ClassDB::bind_method(D_METHOD("cancel_location"), &CompanionIOS::cancel_location);
        ClassDB::bind_method(D_METHOD("poll_events"), &CompanionIOS::poll_events);
        ClassDB::bind_method(D_METHOD("low_power"), &CompanionIOS::low_power);
        ClassDB::bind_method(D_METHOD("reduced_motion"), &CompanionIOS::reduced_motion);
    }
public:
    CompanionIOS() { service = [CourtyardLocation new]; }
    ~CompanionIOS() {
        CourtyardLocation *owned = service;
        dispatch_async(dispatch_get_main_queue(), ^{ [owned cancel]; });
        service = nil;
    }
    void request_location(int64_t request_id) {
        CourtyardLocation *owned = service;
        dispatch_async(dispatch_get_main_queue(), ^{ [owned request:request_id]; });
    }
    void cancel_location() {
        CourtyardLocation *owned = service;
        dispatch_async(dispatch_get_main_queue(), ^{ [owned cancel]; });
    }
    bool low_power() const { @synchronized(service) { return service.powerSaving; } }
    bool reduced_motion() const { @synchronized(service) { return service.reduceMotion; } }
    Array poll_events() {
        Array result;
        for (NSDictionary *item in [service drain]) {
            Dictionary entry;
            for (NSString *key in item) {
                String name = String::utf8(key.UTF8String);
                id value = item[key];
                if ([value isKindOfClass:NSString.class]) entry[name] = String::utf8([value UTF8String]);
                else if ([value isKindOfClass:NSNumber.class]) entry[name] = [value doubleValue];
            }
            result.push_back(entry);
        }
        return result;
    }
};

static CompanionIOS *singleton = nullptr;
void init_companion_ios() {
    ClassDB::register_class<CompanionIOS>();
    singleton = memnew(CompanionIOS);
    Engine::get_singleton()->add_singleton(Engine::Singleton("CompanionIOS", singleton));
}
void deinit_companion_ios() {
    Engine::get_singleton()->remove_singleton("CompanionIOS");
    if (singleton) { memdelete(singleton); singleton = nullptr; }
}
