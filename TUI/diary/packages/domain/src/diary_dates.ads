package Diary_Dates with Pure is
   subtype Year_Number is Positive range 1 .. 9999;
   subtype Month_Number is Positive range 1 .. 12;
   subtype Day_Number is Positive range 1 .. 31;
   type Date is private;
   Invalid_Date : exception;
   function Days_In_Month (Year : Year_Number; Month : Month_Number) return Day_Number;
   function Create (Year : Year_Number; Month : Month_Number; Day : Day_Number) return Date;
   function Year (Value : Date) return Year_Number;
   function Month (Value : Date) return Month_Number;
   function Day (Value : Date) return Day_Number;
   function Image (Value : Date) return String;
   function Parse (Value : String) return Date;
   function Weekday (Value : Date) return Natural;
   function Shift_Days (Value : Date; Amount : Integer) return Date;
   function Shift_Month (Value : Date; Amount : Integer) return Date;
private
   type Date is record
      Year : Year_Number := 2000;
      Month : Month_Number := 1;
      Day : Day_Number := 1;
   end record;
end Diary_Dates;
