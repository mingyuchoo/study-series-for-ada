package body Counters with SPARK_Mode is
   function Increment (Value : Count) return Count is
     (if Value < Count'Last then Value + 1 else Value);
end Counters;
