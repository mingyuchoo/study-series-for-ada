package body Diary_Service is
   function Create
     (Store : in out Diary_Repositories.Repository'Class;
      Item  : Diary_Entries.Entry_Data) return Outcome is
   begin
      if not Diary_Entries.Is_Valid (Item) then
         return Invalid_Entry;
      elsif Store.Contains (Item.Day) then
         return Already_Exists;
      end if;
      Store.Write (Item);
      return Success;
   end Create;

   function Update
     (Store : in out Diary_Repositories.Repository'Class;
      Item  : Diary_Entries.Entry_Data) return Outcome is
   begin
      if not Diary_Entries.Is_Valid (Item) then
         return Invalid_Entry;
      elsif not Store.Contains (Item.Day) then
         return Not_Found;
      end if;
      Store.Write (Item);
      return Success;
   end Update;

   function Delete
     (Store : in out Diary_Repositories.Repository'Class;
      Day   : Diary_Dates.Date) return Outcome is
   begin
      if not Store.Contains (Day) then
         return Not_Found;
      end if;
      Store.Remove (Day);
      return Success;
   end Delete;

   function Read
     (Store : in out Diary_Repositories.Repository'Class;
      Day   : Diary_Dates.Date) return Diary_Repositories.Entry_Result is
   begin
      return Store.Read (Day);
   end Read;

   function Month_Days
     (Store : in out Diary_Repositories.Repository'Class;
      Day   : Diary_Dates.Date) return Day_Markers
   is
      Result : Day_Markers := [others => False];
   begin
      for Number in
        1
        .. Diary_Dates.Days_In_Month
             (Diary_Dates.Year (Day), Diary_Dates.Month (Day))
      loop
         Result (Number) :=
           Store.Contains
             (Diary_Dates.Create
                (Diary_Dates.Year (Day), Diary_Dates.Month (Day), Number));
      end loop;
      return Result;
   end Month_Days;
end Diary_Service;
