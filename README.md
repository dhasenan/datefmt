# datefmt

Date formatting and **parsing** based on `strftime`.

## Usage

Example:

```D
import datefmt;
auto st = SysTime(DateTime(2014, 4, 17, 14, 47, 35), UTC());
writefln(st.format("%a, %d %b %Y %H:%M:%S GMT"));
// Thu, 17 Apr 2014 14:47:35 GMT
```

Most of the formatting options can also be used to parse:

```D
import datefmt;
auto st = "Thu, 17 Apr 2014 14:47:35 GMT".parse("%a, %d %b %Y %H:%M:%S GMT");
assert(st == SysTime(DateTime(2014, 4, 17, 14, 47, 35), UTC()));
```

Yes, there's another date parsing library out there, but that is to take garbage dates and try to
produce something sensible out of it. This is for stricter parsing.


## Dub

Add a dependency on `"datefmt": "~>1.0.0"`.
