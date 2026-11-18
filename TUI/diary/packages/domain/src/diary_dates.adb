package body Diary_Dates is
   function Days_In_Month (Year : Year_Number; Month : Month_Number) return Day_Number is
   begin
      case Month is
         when 2 =>
            return (if Year mod 400 = 0 or else (Year mod 4 = 0 and then Year mod 100 /= 0) then 29 else 28);
         when 4 | 6 | 9 | 11 => return 30;
         when others => return 31;
      end case;
   end Days_In_Month;

   function Create (Year : Year_Number; Month : Month_Number; Day : Day_Number) return Date is
   begin
      if Day > Days_In_Month (Year, Month) then
         raise Invalid_Date with "Invalid day for month";
      end if;
      return (Year, Month, Day);
   end Create;

   function Year (Value : Date) return Year_Number is (Value.Year);
   function Month (Value : Date) return Month_Number is (Value.Month);
   function Day (Value : Date) return Day_Number is (Value.Day);

   function Image (Value : Date) return String is
      Result : String := "0000-00-00";
      Remaining : Natural := Value.Year;
   begin
      for Index in reverse 1 .. 4 loop
         Result (Index) := Character'Val (Character'Pos ('0') + Remaining mod 10);
         Remaining := Remaining / 10;
      end loop;
      Result (6) := Character'Val (Character'Pos ('0') + Value.Month / 10);
      Result (7) := Character'Val (Character'Pos ('0') + Value.Month mod 10);
      Result (9) := Character'Val (Character'Pos ('0') + Value.Day / 10);
      Result (10) := Character'Val (Character'Pos ('0') + Value.Day mod 10);
      return Result;
   end Image;

   function Parse (Value : String) return Date is
      Text : constant String (1 .. Value'Length) := Value;
   begin
      if Text'Length /= 10 or else Text (5) /= '-' or else Text (8) /= '-' then
         raise Invalid_Date with "Expected YYYY-MM-DD";
      end if;
      for Index in Text'Range loop
         if Index not in 5 | 8 and then Text (Index) not in '0' .. '9' then
            raise Invalid_Date with "Expected numeric date";
         end if;
      end loop;
      return Create (Year_Number'Value (Text (1 .. 4)), Month_Number'Value (Text (6 .. 7)), Day_Number'Value (Text (9 .. 10)));
   exception
      when Constraint_Error => raise Invalid_Date with "Date outside supported range";
   end Parse;

   function Ordinal (Value : Date) return Natural is
      Previous_Year : constant Natural := Value.Year - 1;
      Result : Natural := 365 * Previous_Year + Previous_Year / 4 - Previous_Year / 100 + Previous_Year / 400 + Value.Day - 1;
   begin
      for Current_Month in 1 .. Value.Month - 1 loop
         Result := Result + Days_In_Month (Value.Year, Current_Month);
      end loop;
      return Result;
   end Ordinal;

   function Weekday (Value : Date) return Natural is (Ordinal (Value) mod 7);

   function From_Ordinal (Value : Natural) return Date is
      Low : Year_Number := 1;
      High : Year_Number := 9999;
      Middle : Year_Number;
      Result_Month : Month_Number := 1;
      Remaining : Natural;
   begin
      while Low < High loop
         Middle := (Low + High + 1) / 2;
         if Ordinal (Create (Middle, 1, 1)) <= Value then
            Low := Middle;
         else
            High := Middle - 1;
         end if;
      end loop;
      Remaining := Value - Ordinal (Create (Low, 1, 1));
      while Remaining >= Days_In_Month (Low, Result_Month) loop
         Remaining := Remaining - Days_In_Month (Low, Result_Month);
         Result_Month := Result_Month + 1;
      end loop;
      return Create (Low, Result_Month, Remaining + 1);
   end From_Ordinal;

   function Shift_Days (Value : Date; Amount : Integer) return Date is
      Target : constant Long_Long_Integer := Long_Long_Integer (Ordinal (Value)) + Long_Long_Integer (Amount);
      Maximum : constant Long_Long_Integer := Long_Long_Integer (Ordinal (Create (9999, 12, 31)));
   begin
      return From_Ordinal (Natural (Long_Long_Integer'Max (0, Long_Long_Integer'Min (Maximum, Target))));
   end Shift_Days;

   function Shift_Month (Value : Date; Amount : Integer) return Date is
      Target : constant Long_Long_Integer := Long_Long_Integer (Value.Year - 1) * 12 + Long_Long_Integer (Value.Month - 1) + Long_Long_Integer (Amount);
      Bounded : constant Natural := Natural (Long_Long_Integer'Max (0, Long_Long_Integer'Min (9999 * 12 - 1, Target)));
      New_Year : constant Year_Number := Bounded / 12 + 1;
      New_Month : constant Month_Number := Bounded mod 12 + 1;
   begin
      return Create (New_Year, New_Month, Day_Number'Min (Value.Day, Days_In_Month (New_Year, New_Month)));
   end Shift_Month;
end Diary_Dates;
