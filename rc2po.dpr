program rc2po;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  Classes,
  Math;

var
  EnUs, Lang, Dest: string;
  EnUsF, LangF, DestF: TStringList;

procedure RebuildFilter(var DeQuotedFilter: string);
var
  I: integer;

  Result, Temp, S: string;
  Elements, Types: TArray<string>;
begin
  if pos('\0', DeQuotedFilter) = 0 then
    exit;

  Result := '';
  Elements := DeQuotedFilter.Split(['\0']);

  if length(Elements) > 0 then
    for I := 0 to High(Elements) do
      if Elements[I] = '' then
        continue
      else if not odd(I) then begin
        if I <> 0 then
          Result := Result + ';;';

        Result := Result + Copy(Elements[I], 1, Elements[I].IndexOf('(') + 1);
      end
      else begin
        Types := Elements[I].Split([';']);
        Temp := '';
        for S in Types do
          if S = '*.*' then
            Temp := Temp + '* '
          else if LowerCase(S) = UpperCase(S) then
            Temp := Temp + S + ' '
          else
            Temp := Temp + UpperCase(S) + ' ' + LowerCase(S) + ' ';

        Result := Result + TrimRight(Temp) + ')';
      end;

  if Result <> '' then
    DeQuotedFilter := Result;
end;

function Parse(const FileName: string): TStringList;
var
  F: TextFile;

  S, E, I: integer;
  Line: string;

  Defines: TStringList;
begin
  Result := TStringList.Create;
  Defines := TStringList.Create;

  AssignFile(F, FileName);
  Reset(F);
  try
    while not Eof(F) do begin
      ReadLn(F, Line);
      Line := Line.Replace(#9, ' ', [rfReplaceAll]);

      if (pos('#define', Line) = 1) then begin
        S := Line.IndexOf(' ');
        E := Line.IndexOf(' ', S + 1);

        if (S <> -1) and (E <> -1) and (S <> E) then
          Defines.Values[
            '" ' + Trim(Line.Substring(S, E - S + 1)) + ' "'] :=
            Trim(Line.Substring(E + 1)).DeQuotedString('"');
      end;

      if pos('#include', Line) = 1 then
        continue;

      S := Line.IndexOf('"');
      E := Line.LastIndexOf('"');

      if (S <> -1) and (E <> -1) and (S <> E) then begin
        Line := Line.Substring(S, E - S + 1);

        for I := 0 to Defines.Count - 1 do
          Line := Line.Replace(Defines.Names[I], Defines.ValueFromIndex[I], [rfReplaceAll]);

        if Line = '""' then
          continue;

        Line := Line.DeQuotedString('"');

        //- Here you can do final changes to the parsed strings

        RebuildFilter(Line);
        Line := Line.Replace('"','\"', [rfReplaceAll]);

        //- Until there.

        Result.Add('"' + Line + '"');
      end;
    end;
  finally
    CloseFile(F);
    Defines.Free;
  end;
end;

procedure CreatePO(const EnUsF, LangF, DestF: TStringList);
var
  I, C, Ig: Integer;

  Completed: TStringList;
const
  TranslatedBy = '"Translated by"';
  Unknown = '"Unknown"';
begin
  if LangF.Count = EnUsF.Count then begin
    EnUsF.Insert(0, TranslatedBy);
    LangF.Insert(0, Unknown);
  end
  else if LangF.Count = EnUsF.Count + 1 then
    EnUsF.Insert(0, TranslatedBy)
  else
    WriteLn('The translation is incomplete, can result in messed up .PO file!');

  Completed := TStringList.Create;
  try
    C := 0;
    Ig := 0;
    DestF.Clear;
    for I := 0 to Min(EnUsF.Count, LangF.Count) - 1 do
      if Completed.IndexOf(EnUsF[I]) = -1 then
        with DestF do begin
          Add('msgid ' + EnUsF[I]);
          Add('msgstr ' + LangF[I]);
          Add('');
          Completed.Add(EnUsF[I]);
          inc(C);
        end
      else
        inc(Ig);
  finally
    Completed.Free;
  end;

  WriteLn('Template: ', EnUsF.Count, ' strings');
  WriteLn('Translation: ', LangF.Count, ' strings');
  WriteLn('Output: ', C, ' strings');
  WriteLn('Duplicate entries: ', Ig, ' strings');
end;

procedure Help;
begin
  WriteLn('Usage: ', ExtractFileName(paramstr(0)), ' <en-US.RC> <lang.RC> [lang.PO]');
  Halt(1);
end;

begin
  case paramcount of
    0, 1: Help;
    else begin
      if FileExists(paramstr(1)) and FileExists(paramstr(2)) then begin
        EnUs := paramstr(1);
        Lang := paramstr(2);
      end
      else
        Help;
    end;
  end;

  if (paramcount >= 3) then
    Dest := paramstr(3)
  else
    Dest := ChangeFileExt(Lang, '.po');


  DestF := TStringList.Create;
  try
    try
      EnUsF := Parse(EnUs);
      LangF := Parse(Lang);

      try
        CreatePO(EnUsF, LangF, DestF);
        DestF.SaveToFile(Dest);
      finally
        EnUsF.Free;
        LangF.Free;
      end;
    finally
      DestF.Free;
    end;
  except
    on E: Exception do begin
      WriteLn('Exception happened: ', E.Message);
      Halt(2);
    end;
  end;
end.
