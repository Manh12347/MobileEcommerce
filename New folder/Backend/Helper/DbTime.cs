using System;

namespace PTVBTPM.Helper
{
    /// <summary>
    /// Helper class for handling database time operations
    /// Ensures consistent timestamp without time zone handling for PostgreSQL
    /// </summary>
    public static class DbTime
    {
        /// <summary>
        /// Gets today's date as DateTime with unspecified kind
        /// This is used for database operations where we don't want timezone conversions
        /// </summary>
        public static DateTime Today()
        {
            return ToUnspecified(DateTime.Today);
        }

        /// <summary>
        /// Converts a DateTime to unspecified kind (removes timezone information)
        /// This ensures consistent storage in PostgreSQL timestamp without time zone columns
        /// </summary>
        public static DateTime ToUnspecified(DateTime dateTime)
        {
            if (dateTime.Kind == DateTimeKind.Unspecified)
                return dateTime;

            return DateTime.SpecifyKind(dateTime, DateTimeKind.Unspecified);
        }

        /// <summary>
        /// Gets current UTC time as unspecified DateTime
        /// Use this for database timestamps that should be consistent across timezones
        /// </summary>
        public static DateTime UtcNowUnspecified()
        {
            return ToUnspecified(DateTime.UtcNow);
        }

        /// <summary>
        /// Gets current local time as unspecified DateTime
        /// </summary>
        public static DateTime NowUnspecified()
        {
            return ToUnspecified(DateTime.Now);
        }
    }
}
