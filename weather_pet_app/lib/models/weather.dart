class WeatherData {
  final String condition;
  final double temperature;
  final double humidity;
  final double windSpeed;
  String cityName;
  final double feelsLike;

  WeatherData({
    this.condition = 'clear',
    this.temperature = 22.0,
    this.humidity = 50.0,
    this.windSpeed = 5.0,
    this.cityName = '定位中…',
    this.feelsLike = 22.0,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      condition: json['condition'] ?? 'clear',
      temperature: (json['temperature'] ?? 22.0).toDouble(),
      humidity: (json['humidity'] ?? 50.0).toDouble(),
      windSpeed: (json['wind_speed'] ?? 5.0).toDouble(),
      cityName: json['city_name'] ?? '未知',
      feelsLike: (json['feels_like'] ?? json['temperature'] ?? 22.0).toDouble(),
    );
  }

  String get conditionLabel {
    const labels = {
      'clear': '晴朗', 'cloudy': '多云', 'overcast': '阴天',
      'rain': '下雨', 'drizzle': '小雨', 'heavy_rain': '大雨',
      'thunderstorm': '雷阵雨', 'snow': '下雪', 'heavy_snow': '大雪',
      'fog': '雾', 'haze': '霾', 'sandstorm': '沙尘暴', 'windy': '大风',
    };
    return labels[condition] ?? '晴朗';
  }

  String get conditionIcon {
    const icons = {
      'clear': '☀️', 'cloudy': '⛅', 'overcast': '☁️',
      'rain': '🌧', 'drizzle': '🌦', 'heavy_rain': '🌧',
      'thunderstorm': '⛈', 'snow': '❄️', 'heavy_snow': '🌨',
      'fog': '🌫', 'haze': '🌫', 'sandstorm': '🌪', 'windy': '💨',
    };
    return icons[condition] ?? '☀️';
  }

  bool get isRaining =>
      condition == 'rain' || condition == 'drizzle' || condition == 'heavy_rain';
  bool get isStormy => condition == 'thunderstorm';
  bool get isSnowing => condition == 'snow' || condition == 'heavy_snow';
  bool get isFoggy => condition == 'fog' || condition == 'haze';
  bool get isWindy => condition == 'windy';
  bool get isHot => temperature > 35;
  bool get isCold => temperature < 5;
}

enum PetState {
  idle,
  walking,
  sleeping,
  eating,
  waving,
  jumping,
  spinning,
  rainUmbrella,
  stormScared,
  snowCatch,
  snowFight,
  coldShiver,
  hotMelt,
  windLean,
  fogWander,
  lowBattery,
  phoneScroll,
  festival,
  playDead,
  overcastIdle,
}

extension PetStateExtension on PetState {
  String get label {
    const labels = {
      PetState.idle: '😌 发呆中',
      PetState.walking: '🚶 散步中',
      PetState.sleeping: '😴 深度睡眠',
      PetState.eating: '🍽 干饭中',
      PetState.waving: '👋 招手!',
      PetState.jumping: '🤸 跳跃!',
      PetState.spinning: '🌀 转圈圈!',
      PetState.rainUmbrella: '☂️ 撑伞挡雨',
      PetState.stormScared: '⚡ 害怕打雷',
      PetState.snowCatch: '❄️ 接雪花',
      PetState.snowFight: '⛄ 打雪仗',
      PetState.coldShiver: '🥶 冷得发抖',
      PetState.hotMelt: '🥵 热化了',
      PetState.windLean: '💨 顶风前行',
      PetState.fogWander: '🌫️ 雾里溜达',
      PetState.lowBattery: '🪫 快没电了',
      PetState.phoneScroll: '📱 刷手机',
      PetState.festival: '🎉 过节啦!',
      PetState.playDead: '💫 趴下了',
      PetState.overcastIdle: '☁️ 阴沉沉',
    };
    return labels[this] ?? '😊 陪伴你';
  }
}
