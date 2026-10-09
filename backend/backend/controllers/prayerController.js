import { getPrayerTimesFromAPI, getNextPrayer as getNextPrayerService } from '../services/prayerService.js';

export const getPrayerTimes = async (req, res, next) => {
  try {
    const { city = 'Karachi', country = 'Pakistan', method = 3, school = 1, date } = req.query;
    const data = await getPrayerTimesFromAPI(city, country, parseInt(method), parseInt(school), date);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
};

export const getNextPrayer = async (req, res, next) => {
  try {
    const { city = 'Karachi', country = 'Pakistan', method = 3, school = 1 } = req.query;
    const data = await getPrayerTimesFromAPI(city, country, parseInt(method), parseInt(school));
    const nextPrayer = getNextPrayerService(data.prayers);

    res.json({
      success: true,
      data: {
        currentTime: new Date().toLocaleTimeString(),
        nextPrayer,
        allPrayers: data.prayers,
        hijri: data.hijri,
      },
    });
  } catch (error) {
    next(error);
  }
};
