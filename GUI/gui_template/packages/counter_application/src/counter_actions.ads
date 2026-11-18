with Counters;

package Counter_Actions with Pure, SPARK_Mode is
   subtype Count is Counters.Count;
   use type Count;

   Initial_Count : constant Count := Count'First;

   type Action is (Increment, Reset);

   function Apply (Value : Count; Event : Action) return Count
     with Global => null,
          Contract_Cases =>
            (Event = Increment =>
               Apply'Result =
                 (if Value < Count'Last
                  then Value + 1
                  else Count'Last),
             Event = Reset => Apply'Result = Initial_Count);
end Counter_Actions;
