import Foundation

/// The 16 scenes of the yard and the preset cities. Port of `companion/catalog.gd`.
public enum Catalog {
    public static let ids = ["clear", "cloudy", "overcast", "drizzle", "rain", "heavy_rain", "thunderstorm", "snow", "heavy_snow", "windy", "fog", "hot", "cold", "dawn", "dusk", "night"]
    static let titles = ["晴天", "多云", "阴天", "细雨", "下雨", "大雨", "雷雨", "飘雪", "大雪", "大风", "薄雾", "酷热", "寒冷", "清晨", "黄昏", "深夜"]
    static let temps: [Double] = [24, 22, 19, 18, 16, 14, 15, -2, -6, 17, 12, 36, -8, 17, 21, 18]
    static let captions = ["阳光刚刚好，想陪你待一会儿。", "云慢慢走，今天也不用着急。", "天有点阴，小院依然很安静。", "好像有雨点，伸手试试看。", "一起等这场雨慢慢过去。", "雨下大了，伞要握稳一点。", "有点怕雷，不过有你在。", "第一片雪花，落在手心里。", "院子变白了，记得暖暖手。", "风把头发吹乱啦。", "远处朦朦胧胧，慢一点走。", "今天好热，休息一下再出发。", "把围巾裹好，等一杯热饮。", "早安，今天也一起长大一点。", "天色暖起来了，今天辛苦啦。", "灯还亮着，陪你说一声晚安。"]

    public struct City: Equatable, Sendable {
        public let name: String
        public let lat: Double
        public let lon: Double
    }

    public static let cities = [
        City(name: "上海", lat: 31.23, lon: 121.47), City(name: "北京", lat: 39.90, lon: 116.40),
        City(name: "杭州", lat: 30.27, lon: 120.15), City(name: "深圳", lat: 22.54, lon: 114.06),
        City(name: "广州", lat: 23.13, lon: 113.26), City(name: "成都", lat: 30.57, lon: 104.07),
        City(name: "武汉", lat: 30.59, lon: 114.30), City(name: "西安", lat: 34.34, lon: 108.94),
        City(name: "哈尔滨", lat: 45.80, lon: 126.53), City(name: "昆明", lat: 25.04, lon: 102.72),
        City(name: "香港", lat: 22.32, lon: 114.17), City(name: "台北", lat: 25.03, lon: 121.57),
    ]

    public static func preset(_ id: String) -> WeatherEnvironment {
        let i = ids.firstIndex(of: id) ?? 0
        let id = ids[i]
        return WeatherEnvironment(
            id: id, title: titles[i], temperature: temps[i], feels: temps[i],
            wind: id == "windy" ? 38 : 10, humidity: isRain(id) ? 85 : 50,
            isDay: id != "night",
            hour: id == "night" ? 23 : (id == "dawn" ? 6 : (id == "dusk" ? 18 : 12)),
            caption: captions[i])
    }

    public static func title(_ id: String) -> String { preset(id).title }

    public static func isRain(_ id: String) -> Bool {
        ["drizzle", "rain", "heavy_rain", "thunderstorm"].contains(id)
    }

    public static func isSnow(_ id: String) -> Bool {
        ["snow", "heavy_snow"].contains(id)
    }

    public static func fromWMO(code: Int, temp: Double, wind: Double) -> String {
        if code >= 95 { return "thunderstorm" }
        if [71, 73, 75, 77, 85, 86].contains(code) { return [75, 86].contains(code) ? "heavy_snow" : "snow" }
        if [65, 67, 82].contains(code) { return "heavy_rain" }
        if [61, 63, 66, 80, 81].contains(code) { return "rain" }
        if [51, 53, 55, 56, 57].contains(code) { return "drizzle" }
        if [45, 48].contains(code) { return "fog" }
        if temp >= 33 { return "hot" }
        if temp <= 3 { return "cold" }
        if wind >= 28 { return "windy" }
        if code == 3 { return "overcast" }
        if code == 2 { return "cloudy" }
        return "clear"
    }
}

/// What the yard currently feels like. `phase`/`minute` are only filled for live weather.
public struct WeatherEnvironment: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var temperature: Double
    public var feels: Double
    public var wind: Double
    public var humidity: Double
    public var isDay: Bool
    public var hour: Int
    public var minute: Int?
    public var phase: String?
    public var caption: String

    public init(id: String, title: String, temperature: Double, feels: Double, wind: Double, humidity: Double, isDay: Bool, hour: Int, minute: Int? = nil, phase: String? = nil, caption: String) {
        self.id = id
        self.title = title
        self.temperature = temperature
        self.feels = feels
        self.wind = wind
        self.humidity = humidity
        self.isDay = isDay
        self.hour = hour
        self.minute = minute
        self.phase = phase
        self.caption = caption
    }
}
