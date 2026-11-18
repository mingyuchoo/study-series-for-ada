package Counters with Pure, SPARK_Mode is
   type Count is range 0 .. 999;

   function Increment (Value : Count) return Count
     with Global => null,
          Post =>
            Increment'Result =
              (if Value < Count'Last then Value + 1 else Count'Last);
end Counters;
