@interface WUIDynamicWeatherBackground : UIView
@end

@interface WeatherLockManager : NSObject {
    UIView *lockView, *homeView;
    WUIDynamicWeatherBackground *lockWeather, *homeWeather;
}
@property (retain, nonatomic, readwrite) UIView *lockView, *homeView;
@property (retain, nonatomic, readwrite) WUIDynamicWeatherBackground *lockWeather, *homeWeather;

+ (instancetype)sharedInstance;

@end
