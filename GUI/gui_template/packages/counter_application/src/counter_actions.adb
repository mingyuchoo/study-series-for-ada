package body Counter_Actions with SPARK_Mode is
   function Apply (Value : Count; Event : Action) return Count is
     (case Event is
         when Increment => Counters.Increment (Value),
         when Reset     => Initial_Count);
end Counter_Actions;
