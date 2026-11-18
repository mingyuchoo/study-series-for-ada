package Diary_Tooling_Release is
   function Manifest_Version (Source : String) return String;
   function Pin_Manifest (Source : String) return String;
   function Dependencies_Allowed (Source, Platform : String) return Boolean;
end Diary_Tooling_Release;
