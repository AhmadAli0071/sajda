import axios from 'axios';

const AL_ADHAN_BASE = 'http://api.aladhan.com/v1';

export const getPrayerTimesFromAPI = async (city, country, method = 3, school = 1, date = null) => {
  try {
    const params = { city, country, method, school };
    if (date) {
      // Clients send YYYY-MM-DD; AlAdhan expects DD-MM-YYYY. Without this
      // the calendar day-sheet would always show today's times.
      const [y, m, d] = String(date).split('-');
      if (y && m && d) params.date = `${d}-${m}-${y}`;
    }
    const response = await axios.get(`${AL_ADHAN_BASE}/timingsByCity`, {
      params,
    });

    const data = response.data.data;

    const timings = data.timings;
    const prayers = [
      { name: 'Fajr', time: timings.Fajr },
      { name: 'Sunrise', time: timings.Sunrise },
      { name: 'Dhuhr', time: timings.Dhuhr },
      { name: 'Asr', time: timings.Asr },
      { name: 'Maghrib', time: timings.Maghrib },
      { name: 'Isha', time: timings.Isha },
    ];

    const hijri = data.date.hijri;

    return {
      prayers,
      date: data.date.readable,
      hijri: {
        day: hijri.day,
        month: hijri.month.en,
        monthAr: hijri.month.ar,
        year: hijri.year,
        full: `${hijri.day} ${hijri.month.en} ${hijri.year}`,
        fullAr: `${hijri.day} ${hijri.month.ar} ${hijri.year}`,
      },
      gregorian: data.date.gregorian,
    };
  } catch (error) {
    console.error('Al-Adhan API error:', error.message);
    throw new Error('Failed to fetch prayer times');
  }
};

export const getNextPrayer = (prayers) => {
  const now = new Date();
  const currentMinutes = now.getHours() * 60 + now.getMinutes();

  const prayerTimes = prayers.map(p => {
    const [h, m] = p.time.split(':').map(Number);
    return { ...p, totalMinutes: h * 60 + m };
  });

  const nextPrayers = prayerTimes.filter(p => p.totalMinutes > currentMinutes);

  if (nextPrayers.length === 0) {
    const fajr = prayerTimes.find(p => p.name === 'Fajr');
    return {
      ...fajr,
      isTomorrow: true,
      countdown: calculateCountdown(fajr.totalMinutes, currentMinutes, true),
    };
  }

  const next = nextPrayers[0];
  return {
    ...next,
    isTomorrow: false,
    countdown: calculateCountdown(next.totalMinutes, currentMinutes, false),
  };
};

const calculateCountdown = (targetMinutes, currentMinutes, isTomorrow) => {
  let diffMinutes;
  if (isTomorrow) {
    diffMinutes = (24 * 60 - currentMinutes) + targetMinutes;
  } else {
    diffMinutes = targetMinutes - currentMinutes;
  }
  return diffMinutes * 60;
};

export const getHijriDate = async () => {
  try {
    const response = await axios.get(`${AL_ADHAN_BASE}/currentDate`, {
      params: { method: 1 },
    });
    return response.data;
  } catch (error) {
    throw new Error('Failed to fetch Hijri date');
  }
};
