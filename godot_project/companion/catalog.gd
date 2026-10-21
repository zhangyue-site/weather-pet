extends RefCounted

const IDS = ["clear", "cloudy", "overcast", "drizzle", "rain", "heavy_rain", "thunderstorm", "snow", "heavy_snow", "windy", "fog", "hot", "cold", "dawn", "dusk", "night"]
const TITLES = ["晴天", "多云", "阴天", "细雨", "下雨", "大雨", "雷雨", "飘雪", "大雪", "大风", "薄雾", "酷热", "寒冷", "清晨", "黄昏", "深夜"]
const TEMPS = [24, 22, 19, 18, 16, 14, 15, -2, -6, 17, 12, 36, -8, 17, 21, 18]
const CAPTIONS = ["阳光刚刚好，想陪你待一会儿。", "云慢慢走，今天也不用着急。", "天有点阴，小院依然很安静。", "好像有雨点，伸手试试看。", "一起等这场雨慢慢过去。", "雨下大了，伞要握稳一点。", "有点怕雷，不过有你在。", "第一片雪花，落在手心里。", "院子变白了，记得暖暖手。", "风把头发吹乱啦。", "远处朦朦胧胧，慢一点走。", "今天好热，休息一下再出发。", "把围巾裹好，等一杯热饮。", "早安，今天也一起长大一点。", "天色暖起来了，今天辛苦啦。", "灯还亮着，陪你说一声晚安。"]
const CITIES = [
	{"name":"上海", "lat":31.23, "lon":121.47}, {"name":"北京", "lat":39.90, "lon":116.40},
	{"name":"杭州", "lat":30.27, "lon":120.15}, {"name":"深圳", "lat":22.54, "lon":114.06},
	{"name":"广州", "lat":23.13, "lon":113.26}, {"name":"成都", "lat":30.57, "lon":104.07},
	{"name":"武汉", "lat":30.59, "lon":114.30}, {"name":"西安", "lat":34.34, "lon":108.94},
	{"name":"哈尔滨", "lat":45.80, "lon":126.53}, {"name":"昆明", "lat":25.04, "lon":102.72},
	{"name":"香港", "lat":22.32, "lon":114.17}, {"name":"台北", "lat":25.03, "lon":121.57}
]

static func preset(id: String) -> Dictionary:
	var i: int = IDS.find(id)
	if i < 0: i = 0
	return {"id": IDS[i], "title": TITLES[i], "temperature": float(TEMPS[i]), "feels": float(TEMPS[i]), "wind": 38.0 if id == "windy" else 10.0, "humidity": 85.0 if is_rain(id) else 50.0, "is_day": id != "night", "hour": 23 if id == "night" else (6 if id == "dawn" else (18 if id == "dusk" else 12)), "caption": CAPTIONS[i]}

static func is_rain(id: String) -> bool:
	return id in ["drizzle", "rain", "heavy_rain", "thunderstorm"]

static func is_snow(id: String) -> bool:
	return id in ["snow", "heavy_snow"]

static func from_wmo(code: int, temp: float, wind: float) -> String:
	if code >= 95: return "thunderstorm"
	if code in [71, 73, 75, 77, 85, 86]: return "heavy_snow" if code in [75, 86] else "snow"
	if code in [65, 67, 82]: return "heavy_rain"
	if code in [61, 63, 66, 80, 81]: return "rain"
	if code in [51, 53, 55, 56, 57]: return "drizzle"
	if code in [45, 48]: return "fog"
	if temp >= 33.0: return "hot"
	if temp <= 3.0: return "cold"
	if wind >= 28.0: return "windy"
	if code == 3: return "overcast"
	if code == 2: return "cloudy"
	return "clear"
