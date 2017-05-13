/**
  * datefmt provides parsing and formatting for std.datetime objects.
  *
  * The format is taken from strftime:
  *    %a     The abbreviated name of the day of the week according to the current locale.
  *    %A     The full name of the day of the week according to the current locale.
  *    %b     The abbreviated month name according to the current locale.
  *    %B     The full month name according to the current locale.
  *    %C     The century number (year/100) as a 2-digit integer.
  *    %d     The day of the month as a decimal number (range 01 to 31).
  *    %e     Like %d, the day of the month as a decimal number, but a leading zero is replaced by a space.
  *    %F     Equivalent to %Y-%m-%d (the ISO 8601 date format).
  *    %h     The hour as a decimal number using a 12-hour clock (range 01 to 12).
  *    %H     The hour as a decimal number using a 24-hour clock (range 00 to 23).
  *    %I     The hour as a decimal number using a 12-hour clock (range 00 to 23).
  *    %j     The day of the year as a decimal number (range 001 to 366).
  *    %k     The hour (24-hour clock) as a decimal number (range 0 to 23); single digits are preceded by a blank.  (See also %H.)  (TZ)
  *    %l     The hour (12-hour clock) as a decimal number (range 1 to 12); single digits are preceded by a blank.  (See also %I.)  (TZ)
  *    %m     The month as a decimal number (range 01 to 12).
  *    %M     The minute as a decimal number (range 00 to 59).
  *    %p     Either "AM" or "PM" according to the given time value, or the corresponding strings for the current locale.  Noon is treated as "PM" and midnight as "AM".
  *    %P     Like %p but in lowercase: "am" or "pm" or a corresponding string for the current locale. (GNU)
  *    %r     The time in a.m. or p.m. notation.  In the POSIX locale this is equivalent to %I:%M:%S %p.
  *    %R     The time in 24-hour notation (%H:%M).  For a version including the seconds, see %T below.
  *    %s     The number of seconds since the Epoch, 1970-01-01 00:00:00 +0000 (UTC). (TZ)
  *    %S     The second as a decimal number (range 00 to 60).  (The range is up to 60 to allow for occasional leap seconds.)
  *    %T     The time in 24-hour notation (%H:%M:%S).
  *    %u     The day of the week as a decimal, range 1 to 7, Monday being 1.  See also %w.
  *    %V     The  ISO 8601 week number (see NOTES) of the current year as a decimal number, range 01 to 53, where week 1 is the first week that has at least 4 days in the new year.  See
  *           also %U and %W.
  *    %w     The day of the week as a decimal, range 0 to 6, Sunday being 0.  See also %u.
  *    %W     The week number of the current year as a decimal number, range 00 to 53, starting with the first Monday as the first day of week 01.
  *    %y     The year as a decimal number without a century (range 00 to 99).
  *    %Y     The year as a decimal number including the century.
  *    %z     The +hhmm or -hhmm numeric timezone (that is, the hour and minute offset from UTC).
  *    %Z     The timezone name or abbreviation.
  *    %%     A literal '%' character.
  */
module datefmt;

import core.time;
import std.array;
import std.conv;
import std.datetime;
import std.string;
import std.utf : codeLength;
alias to = std.conv.to;

enum weekdayNames = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday"
];

enum weekdayAbbrev = [
    "Sun",
    "Mon",
    "Tues",
    "Wed",
    "Thurs",
    "Fri",
    "Sat"
];

enum monthNames = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
];

enum monthAbbrev = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
];

/**
 * Format the given datetime with the given format string.
 */
string format(SysTime dt, string formatString)
{
    Appender!string ap;
    bool inPercent;
    foreach (i, c; formatString)
    {
        if (inPercent)
        {
            interpretIntoString(ap, dt, c);
        }
        else if (c == '%')
        {
            inPercent = true;
        }
        else
        {
            ap ~= c;
        }
    }
    return ap.data;
}


/**
 * Parse the given datetime string with the given format string.
 *
 * This tries rather hard to produce a reasonable result. If the format string doesn't describe an
 * unambiguous point time, the result will be a date that satisfies the inputs and should generally
 * be the earliest such date. However, that is not guaranteed.
 *
 * For instance:
 * ---
 * SysTime time = parse("%d", "21");
 * writeln(time);  // 0000-01-21T00:00:00.000000Z
 * ---
 */
SysTime parse(string data, string formatString, immutable(TimeZone) defaultTimeZone = null)
{
    return SysTime.init;
}

private:

struct Interpreter
{
    this(string data)
    {
        this.data = data;
    }
    string data;

    int year;
    int century;
    int yearOfCentury;
    Month month;
    int dayOfWeek;
    int dayOfMonth;
    int dayOfYear;
    int isoWeek;
    int hour12;
    int hour24;
    int hour;
    int minute;
    int second;
    int nanosecond;
    int weekNumber;
    Duration tzOffset;
    string tzAbbreviation;
    string tzName;
    long epochSecond;
    enum AMPM { AM, PM, None };
    AMPM amPm = AMPM.None;

    SysTime parse(string formatString, immutable(TimeZone) defaultTimeZone = null)
    {
        auto tz = defaultTimeZone ? defaultTimeZone : UTC();
        bool inPercent;
        foreach (size_t i, dchar c; formatString)
        {
            if (inPercent)
            {
                interpretFromString(c);
            }
            else if (c == '%')
            {
                inPercent = true;
            }
            else
            {
                // TODO non-ASCII
                data = data[1..$];
            }
        }
        SysTime st;
        if (year)
        {
            st.year = year;
        }
        else
        {
            st.year = century * 100 + yearOfCentury;
        }

        st.month = month;
        st.day = dayOfMonth;
        if (hour12)
        {
            if (amPm == AMPM.PM)
            {
                auto h = hour12 + 12;
                if (h == 24) h = 0;
                st.hour = h;
            }
            else
            {
                st.hour = hour12;
            }
        }
        else
        {
            st.hour = hour24;
        }
        st.minute = minute;
        st.second = second;
        return st;
    }

    bool interpretFromString(dchar c)
    {
        switch (c)
        {
            case 'a':
                foreach (i, m; weekdayAbbrev)
                {
                    if (data.startsWith(m))
                    {
                        data = data[m.length .. $];
                        return true;
                    }
                }
                return false;
            case 'A':
                foreach (i, m; weekdayNames)
                {
                    if (data.startsWith(m))
                    {
                        data = data[m.length .. $];
                        return true;
                    }
                }
                return false;
            case 'b':
                foreach (i, m; monthAbbrev)
                {
                    if (data.startsWith(m))
                    {
                        month = cast(Month)(i + 1);
                        data = data[m.length .. $];
                        return true;
                    }
                }
                return false;
            case 'B':
                foreach (i, m; monthNames)
                {
                    if (data.startsWith(m))
                    {
                        month = cast(Month)(i + 1);
                        data = data[m.length .. $];
                        return true;
                    }
                }
                return false;
            case 'C':
                return parseInt!(x => century = x)(data);
            case 'd':
                return parseInt!(x => dayOfMonth = x)(data);
            case 'e':
                return parseInt!(x => dayOfMonth = x)(data);
            case 'F':
                auto dash1 = data.indexOf('-');
                if (dash1 <= 0) return false;
                if (dash1 >= data.length - 1) return false;
                auto yearStr = data[0..dash1];
                auto year = yearStr.to!int;
                data = data[dash1 + 1 .. $];

                if (data.length < 5)
                {
                    // Month is 2 digits; day is 2 digits; dash between
                    return false;
                }
                if (data[2] != '-')
                {
                    return false;
                }
                if (!parseInt!(x => month = cast(Month)x)(data)) return false;
                if (!data.startsWith("-")) return false;
                data = data[1..$];
                return parseInt!(x => dayOfMonth = x)(data);
            case 'H':
            case 'k':
                return parseInt!(x => hour24 = x)(data);
            case 'h':
            case 'I':
            case 'l':
                return parseInt!(x => hour12 = x)(data);
            case 'j':
                return parseInt!(x => dayOfYear = x, 3)(data);
            case 'm':
                return parseInt!(x => month = cast(Month)x)(data);
            case 'M':
                return parseInt!(x => minute = x)(data);
            case 'p':
                if (data.startsWith("AM"))
                {
                    amPm = AMPM.AM;
                }
                else if (data.startsWith("PM"))
                {
                    amPm = AMPM.PM;
                }
                else
                {
                    return false;
                }
                return true;
            case 'P':
                if (data.startsWith("am"))
                {
                    amPm = AMPM.AM;
                }
                else if (data.startsWith("pm"))
                {
                    amPm = AMPM.PM;
                }
                else
                {
                    return false;
                }
                return true;
            case 'r':
                return interpretFromString('I') &&
                    pop(':') &&
                    interpretFromString('M') &&
                    pop(':') &&
                    interpretFromString('S') &&
                    pop(' ') &&
                    interpretFromString('p');
            case 'R':
                return interpretFromString('H') &&
                    pop(':') &&
                    interpretFromString('M');
            case 's':
                size_t end = 0;
                foreach (i2, c2; data)
                {
                    if (c2 < '0' || c2 > '9')
                    {
                        end = cast()i2;
                        break;
                    }
                }
                if (end == 0) return false;
                epochSecond = data[0..end].to!int;
                data = data[end..$];
                return true;
            case 'S':
                return parseInt!(x => seconds = x)(data);
            case 'T':
                return interpretFromString('H') &&
                    pop(':') &&
                    interpretFromString('M') &&
                    pop(':') &&
                    interpretFromString('S');
            case 'u':
                return parseInt!(x => dayOfWeek = cast(DayOfWeek)(x % 7))(data);
            case 'V':
                return parseInt!(x => isoWeek = x)(data);
            case 'y':
                return parseInt!(x => yearOfCentury = x)(data);
            case 'Y':
                size_t end = 0;
                foreach (i2, c2; data)
                {
                    if (c2 < '0' || c2 > '9')
                    {
                        end = i2;
                        break;
                    }
                }
                if (end == 0) return false;
                year = data[0..end].to!int;
                data = data[end..$];
                return true;
            case 'z':
                int sign = 0;
                if (pop('-'))
                {
                    sign = -1;
                }
                else if (pop('+'))
                {
                    sign = 1;
                }
                else
                {
                    return false;
                }
                int hour, minute;
                parseInt!(x => hour = x)(data);
                parseInt!(x => minute = x)(data);
                tzOffset = dur!"minutes"(sign * (minute + 60 * hour));
                return true;
            case 'Z':
                // Oh god.
                // This could be something like America/Los_Angeles.
                // Or UTC.
                // Or EST5EDT.
                // And it could be followed by anything. Like the format might be:
                //  "%Z%a" -> America/Los_AngelesMon
                // I'll assume that this is followed by a space or something.
                return parseInt!(x => isoWeek = x)(data);
            default:
                throw new Exception("unrecognized control character %s");
        }
    }

    bool pop(dchar c)
    {
        if (data.startsWith(c))
        {
            data = data[c.codeLength!char .. $];
            return true;
        }
        return false;
    }
}

    bool parseInt(alias setter, int length = 2)(ref string data)
    {
        if (data.length < length)
        {
            return false;
        }
        auto c = data[0..length];
        data = data[length..$].strip;
        int v;
        try
        {
            v = c.to!int;

        }
        catch (ConvException e)
        {
            return false;
        }
        cast(void)setter(c.to!int);
        return true;
    }

void interpretIntoString(ref Appender!string ap, SysTime dt, char c)
{
    switch (c)
    {
        case 'a':
            ap ~= weekdayAbbrev[cast(size_t)dt.dayOfWeek];
            return;
        case 'A':
            ap ~= weekdayNames[cast(size_t)dt.dayOfWeek];
            return;
        case 'b':
            ap ~= monthAbbrev[cast(size_t)dt.month];
            return;
        case 'B':
            ap ~= monthNames[cast(size_t)dt.month];
            return;
        case 'C':
            ap ~= (dt.year / 100).to!string;
            return;
        case 'd':
            auto s = dt.day.to!string;
            if (s.length == 1)
            {
                ap ~= "0";
            }
            ap ~= s;
            return;
        case 'e':
            auto s = dt.day.to!string;
            if (s.length == 1)
            {
                ap ~= " ";
            }
            ap ~= s;
            return;
        case 'F':
            interpretIntoString(ap, dt, 'Y');
            ap ~= '-';
            interpretIntoString(ap, dt, 'm');
            ap ~= '-';
            interpretIntoString(ap, dt, 'd');
            return;
        case 'g':
            // TODO what is this?
            throw new Exception("%g not yet implemented");
        case 'G':
            // TODO what is this?
            throw new Exception("%G not yet implemented");
        case 'h':
        case 'I':
            auto h = dt.hour;
            if (h == 0)
            {
                h = 12;
            }
            else if (h > 12)
            {
                h -= 12;
            }
            ap.pad(h.to!string, '0', 2);
            return;
        case 'H':
            ap.pad(dt.hour.to!string, '0', 2);
            return;
        case 'j':
            ap.pad(dt.dayOfYear.to!string, '0', 3);
            return;
        case 'k':
            ap.pad(dt.hour.to!string, ' ', 2);
            return;
        case 'l':
            auto h = dt.hour;
            if (h == 0)
            {
                h = 12;
            }
            else if (h > 12)
            {
                h -= 12;
            }
            ap.pad(h.to!string, ' ', 2);
            return;
        case 'm':
            uint m = cast(uint)dt.month;
            ap.pad(m.to!string, '0', 2);
            return;
        case 'M':
            ap.pad(dt.minute.to!string, '0', 2);
            return;
        case 'p':
            if (dt.hour >= 12)
            {
                ap ~= "PM";
            }
            else
            {
                ap ~= "AM";
            }
            return;
        case 'P':
            if (dt.hour >= 12)
            {
                ap ~= "pm";
            }
            else
            {
                ap ~= "am";
            }
            return;
        case 'r':
            interpretIntoString(ap, dt, 'I');
            ap ~= ':';
            interpretIntoString(ap, dt, 'M');
            ap ~= ':';
            interpretIntoString(ap, dt, 'S');
            ap ~= ' ';
            interpretIntoString(ap, dt, 'p');
            return;
        case 'R':
            interpretIntoString(ap, dt, 'H');
            ap ~= ':';
            interpretIntoString(ap, dt, 'M');
            return;
        case 's':
            auto delta = dt - SysTime(DateTime(1970, 1, 1), UTC());
            ap ~= delta.total!"seconds"().to!string;
            return;
        case 'S':
            ap.pad(dt.second.to!string, '0', 2);
            return;
        case 'T':
            interpretIntoString(ap, dt, 'H');
            ap ~= ':';
            interpretIntoString(ap, dt, 'M');
            ap ~= ':';
            interpretIntoString(ap, dt, 'S');
            return;
        case 'u':
            auto dow = cast(uint)dt.dayOfWeek;
            if (dow == 0) dow = 7;
            ap ~= dow.to!string;
            return;
        case 'w':
            ap ~= (cast(uint)dt.dayOfWeek).to!string;
            return;
        case 'y':
            ap.pad((dt.year % 100).to!string, '0', 2);
            return;
        case 'Y':
            ap.pad(dt.year.to!string, '0', 4);
            return;
        case 'z':
            auto d = dt.utcOffset;
            if (d < dur!"seconds"(0))
            {
                ap ~= '-';
            }
            else
            {
                ap ~= '+';
            }
            ap.pad(d.total!"hours"().to!string, '0', 2);
            ap.pad((d.total!"minutes"() % 60).to!string, '0', 2);
            return;
        case 'Z':
            if (dt.dstInEffect)
            {
                ap ~= dt.timezone.stdName;
            }
            else if (dt.timezone is null)
            {
                ap ~= 'Z';
            }
            else
            {
                ap ~= dt.timezone.dstName;
            }
            return;
        case '%':
            ap ~= '%';
            return;
        default:
            throw new Exception("format element %" ~ c ~ " not recognized");
    }
}

void pad(ref Appender!string ap, string s, char pad, uint length)
{
    if (s.length >= length)
    {
        ap ~= s;
        return;
    }
    for (uint i = 0; i < length - s.length; i++)
    {
        ap ~= pad;
    }
    ap ~= s;
}
