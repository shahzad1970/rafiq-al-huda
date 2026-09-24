<?php
// Development parity harness. Not bundled or used to serve app prayer times.
// This constant is needed when upstream enumerates methods; Moonsighting is NOT tested/supported.
namespace Mawaqit\MoonSighting { class Isha { const SHAFAQ_GENERAL = 'general'; } }
namespace {
require __DIR__ . '/../third_party/mawaqit_prayer_times/DMath.php';
require __DIR__ . '/../third_party/mawaqit_prayer_times/Method.php';
$source = file_get_contents(__DIR__ . '/../third_party/mawaqit_prayer_times/PrayerTimes.php');
// Explicitly fix upstream's use of the wall clock in Asr. All other code unchanged.
$old = '$julianDate = $this->gregorianToJulianDate();';
$new = '$julianDate = $this->julianDate($this->date->format("Y"), $this->date->format("n"), $this->date->format("d")) - $this->longitude / 360;';
if (substr_count($source, $old) !== 1) throw new \Exception('Upstream changed');
eval(substr(str_replace($old, $new, $source), 5));
$cases = [];
$cities = [
 ['New York', 40.7128, -74.006, 'America/New_York'],
 ['Makkah', 21.3891, 39.8579, 'Asia/Riyadh'],
 ['Karachi', 24.8607, 67.0011, 'Asia/Karachi'],
 ['Sydney', -33.8688, 151.2093, 'Australia/Sydney'],
 ['London', 51.5074, -0.1278, 'Europe/London'],
 ['Auckland', -36.8485, 174.7633, 'Pacific/Auckland'],
];
foreach ($cities as [$city,$latitude,$longitude,$zone]) {
 foreach (['2026-01-15','2026-03-08','2026-06-21','2026-11-01'] as $day) {
  foreach (\Mawaqit\PrayerTimes\Method::getMethodCodes() as $method) {
   if (in_array($method,['CUSTOM','MOONSIGHTING'])) continue;
   foreach ([false,true] as $hanafi) {
    $date = new \DateTime($day . ' 12:00:00', new \DateTimeZone($zone));
    $calculator = new \Mawaqit\PrayerTimes\PrayerTimes($method,$hanafi?'HANAFI':'STANDARD');
    $times = $calculator->getTimes($date,$latitude,$longitude,0,'ANGLE_BASED',null,'Float');
    $minutes=[];
    foreach (['Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha'] as $prayer) {
      $minutes[$prayer]=(int)floor($times[$prayer]*60+0.5);
    }
    $cases[]=['city'=>$city,'date'=>$day,'latitude'=>$latitude,'longitude'=>$longitude,
      'zone'=>$zone,'offset'=>$date->getOffset()/3600,'method'=>$method,'hanafi'=>$hanafi,'minutes'=>$minutes];
   }
  }
 }
}
echo json_encode(['upstream'=>'640157265aaa4e71e33b8aa718f36f35fb99eb92',
  'modification'=>'Asr uses requested date, not wall clock. See tool/prayer_reference.php.', 'cases'=>$cases],JSON_PRETTY_PRINT|JSON_THROW_ON_ERROR);
}
