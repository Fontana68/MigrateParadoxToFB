TTable (Unità Bde.DBTables):
TTable -> TFDTable
TQuery -> TFDQuery
TDatabase -> TFDConnection
TStoredProc -> TFDStoredProc
TBatchMove	-> TFDBatchMove

TTable (Unità Bde.DBTables): Per connettersi alla tabella Paradox sorgente.
TFDConnection (Unità FireDAC.Comp.Client): Per connettersi al database MOT.fdb.
TFDTable: Per puntare alla tabella di destinazione su Firebird.
TFDBatchMove: L'engine principale della migrazione.
TFDBatchMoveDataSetReader: Collegato alla TTable (BDE).
TFDBatchMoveDataSetWriter: Collegato alla TFDTable (Firebird).

FireDAC’s TFDTable has a property called CachedUpdates. If you enable this, you can let the user edit data in memory and only save it to the disk when they click a "Save" button—making the app feel much faster.

// Drop a TFDConnection on your form
FDConnection1.DriverName := 'SQLite';
FDConnection1.Params.Values['Database'] := 'C:\Data\MyLocalData.sdb';
FDConnection1.Connected := True;

FeatureLegacy VCL (BDE Era)			Modern VCL (Current)
Styling	Default Windows "Gray"		VCL Styles (Light/Dark/Custom)
Layout	Manual $X, Y$ coordinates	TStackPanel, TRelativePanel
Icons	16-color Bitmaps			Anti-aliased SVGs
Grid	TDBGrid (Excel-style)		TControlList (Modern App-style)
DPI		Fixed 96 DPI (Blurry on 4K)	Per-Monitor V2 (Crisp on all screens)

// Delphi 12 Multiline String Feature
  FDQuery1.SQL.Text := 
    '''
    SELECT 
      ID, 
      CustomerName, 
      TotalSales 
    FROM Customers 
    WHERE IsActive = 1 
    ORDER BY CustomerName ASC
    ''';
  FDQuery1.Open;

procedure MigrateBdeToSqlite(BdeTableName: string; SQLiteConnection: TFDConnection);
var
  BdeTable: TTable;
  FidTable: TFDTable;
  BatchMove: TFDBatchMove;
  Reader: TFDBatchMoveDataSetReader;
  Writer: TFDBatchMoveDataSetWriter;
begin
  BdeTable := TTable.Create(nil);
  FidTable := TFDTable.Create(nil);
  BatchMove := TFDBatchMove.Create(nil);
  Reader := TFDBatchMoveDataSetReader.Create(nil);
  Writer := TFDBatchMoveDataSetWriter.Create(nil);
  
  try
    // Setup Source (BDE)
    BdeTable.DatabaseName := 'MyOldBdeAlias';
    BdeTable.TableName := BdeTableName;
    
    // Setup Destination (FireDAC)
    FidTable.Connection := SQLiteConnection;
    FidTable.TableName := 'New_' + BdeTableName;

    // Fast Batch Move Logic
    Reader.DataSet := BdeTable;
    Writer.DataSet := FidTable;
    BatchMove.Reader := Reader;
    BatchMove.Writer := Writer;
    
    // This creates the table structure automatically and moves the data
    BatchMove.Execute;
  finally
    BdeTable.Free;
    FidTable.Free;
    BatchMove.Free;
    Reader.Free;
    Writer.Free;
  end;
end;

procedure TForm1.MigrateEverything;
begin
  // 1. Configure BDE Source
  BdeTable.DatabaseName := 'OldBdeAlias';
  BdeTable.TableName := 'Customer.db';

  // 2. Configure SQLite Destination
  // Connection string: DriverID=SQLite; Database=C:\App\LocalData.db
  SqliteTable.Connection := FDConnection1;
  SqliteTable.TableName := 'Customer'; 

  // 3. Connect the Pump
  FDBatchMoveDataSetReader1.DataSet := BdeTable;
  FDBatchMoveDataSetWriter1.DataSet := SqliteTable;
  
  // Create table structure in SQLite automatically if it doesn't exist
  FDBatchMoveDataSetWriter1.Optimise := True;
  
  // 4. Execute the move
  FDBatchMove1.Execute;
  
  ShowMessage('Table Migrated Successfully!');
end;

// C++Builder 12 Code Snippet
void __fastcall TMainForm::MigrateData() 
{
    // Source: BDE
    BdeTable->DatabaseName = "OldAlias";
    BdeTable->TableName = "Inventory.db";

    // Destination: Firebird (via FireDAC)
    FDConnection1->Params->Values["DriverID"] = "FB";
    FDConnection1->Params->Values["Database"] = "C:\\Data\\App.fdb";
    FDConnection1->Params->Values["Protocol"] = "Local";
    FDConnection1->Connected = true;

    FdTable->Connection = FDConnection1;
    FdTable->TableName = "INVENTORY";

    // The Pump
    FDBatchMoveDataSetReader->DataSet = BdeTable;
    FDBatchMoveDataSetWriter->DataSet = FdTable;
    FDBatchMove->Execute();
}

In BDE, you likely used Table1->Post(). In FireDAC, you do the same, but you should wrap updates in a transaction to ensure data integrity in Firebird:

C++
FDConnection1->StartTransaction();
try {
    FDTable1->Append();
    FDTable1->FieldByName("PART_NAME")->AsString = "New Gear";
    FDTable1->Post();
    FDConnection1->Commit();
} catch (...) {
    FDConnection1->Rollback();
}

TFDBatchMove: The "engine" that coordinates the data transfer.

TFDBatchMoveDataSetReader: The "source" connector. You link this to your old BDE TTable or TQuery.

TFDBatchMoveDataSetWriter: The "destination" connector. You link this to your new FireDAC TFDTable (connected to Firebird).

How to Set It Up (Visual Way)
If you prefer dragging and dropping rather than writing code for the initial migration:

Drop a TFDBatchMove onto your DataModule or Form.

Drop a TFDBatchMoveDataSetReader. Set its DataSet property to your TTable (BDE).

Drop a TFDBatchMoveDataSetWriter. Set its DataSet property to your TFDTable (Firebird).

Click on the TFDBatchMove component and set:

Reader -> FDBatchMoveDataSetReader1

Writer -> FDBatchMoveDataSetWriter1

Right-click the TFDBatchMove component and select Execute, or call FDBatchMove1->Execute() in your code.

#include <FireDAC.Comp.BatchMove.hpp>
#include <FireDAC.Comp.BatchMove.DataSet.hpp>

void __fastcall TMainForm::DoMigration() 
{
    // 1. Create the BatchMove Engine
    std::unique_ptr<TFDBatchMove> batchMove(new TFDBatchMove(nullptr));
    std::unique_ptr<TFDBatchMoveDataSetReader> reader(new TFDBatchMoveDataSetReader(nullptr));
    std::unique_ptr<TFDBatchMoveDataSetWriter> writer(new TFDBatchMoveDataSetWriter(nullptr));

    try {
        // 2. Connect the Reader to the old BDE Table
        reader->DataSet = BdeTable1; 

        // 3. Connect the Writer to the new Firebird Table
        writer->DataSet = FDTable1;
        
        // IMPORTANT: Let FireDAC create the table structure in Firebird automatically
        writer->Options << poIdentityInsert; 

        // 4. Link everything to the engine
        batchMove->Reader = reader.get();
        batchMove->Writer = writer.get();

        // 5. Run the migration
        batchMove->Execute();
        
        ShowMessage("Migration finished successfully!");
    }
    catch (const Exception &e) {
        ShowMessage("Error during migration: " + e.Message);
    }
}

Case Sensitivity: Firebird defaults to UPPERCASE for table and field names. If your BDE table was named customers, Firebird might prefer CUSTOMERS. Check the writer->DataSet->TableName property.

Data Types: Firebird is stricter than BDE/Paradox. Ensure your Firebird table columns are large enough to hold the BDE data (especially strings).

BatchMove Studio: If you want a GUI to design the migration without writing any code at all, look in your Delphi/C++Builder bin folder for FDBatchMoveStudio.exe. It allows you to map fields visually and save the migration as a configuration file.



Creating the Firebird Database Programmatically
In your one-time tool, you don't want the user to have to manually create the database. Use TFDConnection to build it on the fly.

C++
void __fastcall TMigratorForm::CreateTargetDatabase()
{
    FDConnection1->DriverName = "FB";
    FDConnection1->Params->Values["Database"] = "C:\\AppData\\FinalData.fdb";
    FDConnection1->Params->Values["User_Name"] = "sysdba";
    FDConnection1->Params->Values["Password"] = "masterkey";
    FDConnection1->Params->Values["Protocol"] = "Local";
    FDConnection1->Params->Values["CharacterSety"] = "UTF8";

    // This creates the actual .fdb file on the disk
    FDConnection1->CreateDatabase();
    FDConnection1->Connected = true;
}

void __fastcall TMigratorForm::RunFullMigration()
{
    TStringList *tableNames = new TStringList();
    BdeDatabase->GetTableNames(tableNames);

    ProgressBar1->Max = tableNames->Count;
    ProgressBar1->Position = 0;

    for (int i = 0; i < tableNames->Count; i++)
    {
        String currentTable = tableNames->Strings[i];
        MemoLog->Lines->Add("Migrating: " + currentTable + "...");

        BdeTable->TableName = currentTable;
        
        // Point Firebird table to the same name
        FdTable->TableName = currentTable; 

        try {
            // TFDBatchMove logic
            FDBatchMove1->Execute();
            MemoLog->Lines->Add("Success.");
        }
        catch (const Exception &e) {
            MemoLog->Lines->Add("Error in " + currentTable + ": " + e.Message);
        }

        ProgressBar1->Position = i + 1;
        Application->ProcessMessages(); // Keep UI responsive
    }
    delete tableNames;
}

Auto-Increment Fields: Paradox "Auto-Inc" fields don't exist in Firebird. You must create a Generator/Sequence in Firebird. If you use FDBatchMove, set poIdentityInsert in the writer options to keep the old ID numbers intact.

Date Formats: BDE is very forgiving with dates; Firebird is not. If you have "00/00/0000" in Paradox, the migration will fail. You may need to handle the OnGetText event of the BDE field to clean the data before it hits the FireDAC writer.

Reserved Words: If you have a BDE column named Order or User, Firebird will throw an error because those are reserved SQL keywords. You’ll need to map these to something like Order_Num or User_Name in the TFDBatchMove mappings.

Lettura (BDE): Il componente TTable legge il file .db di Paradox tramite l'alias o la cartella BDE.

Pipeline (FireDAC Batch Move): I componenti TFDBatchMove collegano la sorgente alla destinazione, gestendo automaticamente la conversione dei tipi di dati.

Scrittura (FireDAC): Il componente TFDTable scrive i dati nel database Firebird locale MOT.fdb.

uses
  System.SysUtils, System.Classes, Vcl.Dialogs,
  Bde.DBTables, 
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, 
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, 
  FireDAC.Phys, FireDAC.Phys.FB, FireDAC.Comp.Client,
  FireDAC.Comp.BatchMove, FireDAC.Comp.BatchMove.DataSet;

procedure MigraParadoxAFirebirdEmbedded(const BdeAlias, BdeTableName, DestDbPath: string);
var
  FDConnection: TFDConnection;
  FDTable: TFDTable;
  BdeTable: TTable;
  BatchMove: TFDBatchMove;
  Reader: TFDBatchMoveDataSetReader;
  Writer: TFDBatchMoveDataSetWriter;
begin
  // 1. Creazione e configurazione della connessione a Firebird Embedded
  FDConnection := TFDConnection.Create(nil);
  FDTable := TFDTable.Create(nil);
  BdeTable := TTable.Create(nil);
  
  BatchMove := TFDBatchMove.Create(nil);
  Reader := TFDBatchMoveDataSetReader.Create(nil);
  Writer := TFDBatchMoveDataSetWriter.Create(nil);

  try
    // Configurazione dei parametri Firebird per RAD Studio 13.1
    FDConnection.DriverName := 'FB';
    FDConnection.Params.Values['Database'] := DestDbPath; // Es: 'C:\Dati\MOT.fdb'
    FDConnection.Params.Values['User_Name'] := 'SYSDBA';
    FDConnection.Params.Values['Password'] := 'masterkey';
    FDConnection.Params.Values['Protocol'] := 'Local';
    FDConnection.Params.Values['CharacterSet'] := 'UTF8';
    FDConnection.Params.Values['CreateDatabase'] := 'Yes'; // Crea il file MOT.fdb se non esiste

    try
      FDConnection.Open;
    except
      on E: Exception do
      begin
        ShowMessage('Errore nella creazione/connessione del database Firebird: ' + E.Message);
        Exit;
      end;
    end;

    // 2. Configurazione Sorgente (BDE / Paradox)
    BdeTable.DatabaseName := BdeAlias;
    BdeTable.TableName := BdeTableName; // Es: 'Clienti.db'
    BdeTable.Open;

    // 3. Configurazione Destinazione (FireDAC / Firebird)
    FDTable.Connection := FDConnection;
    // Firebird preferisce i nomi delle tabelle in MAIUSCOLO
    FDTable.TableName := UpperCase(ChangeFileExt(BdeTableName, '')); 

    // 4. Configurazione della pipeline BatchMove
    Reader.DataSet := BdeTable;
    Writer.DataSet := FDTable;
    
    // Questa opzione crea automaticamente la tabella su Firebird se non esiste
    Writer.Options := [poIdentityInsert]; 

    BatchMove.Reader := Reader;
    BatchMove.Writer := Writer;

    // 5. Esecuzione del processo di migrazione
    try
      BatchMove.Execute;
      ShowMessage(Format('Tabella %s migrata con successo in MOT.fdb!', [BdeTableName]));
    except
      on E: Exception do
        ShowMessage('Errore durante la migrazione dei record: ' + E.Message);
    end;

  finally
    // Rilascio dei componenti
    BdeTable.Free;
    FDTable.Free;
    FDConnection.Free;
    BatchMove.Free;
    Reader.Free;
    Writer.Free;
  end;
end;

Durante una migrazione da Paradox a Firebird, è comune riscontrare piccoli problemi dovuti alla rigidità di Firebird rispetto al BDE:

Campi Auto-Incrementali: Paradox supporta i campi di tipo + (Autoinc). In Firebird questi campi non esistono nativamente; si utilizzano i Generators (Sequences). L'opzione poIdentityInsert nel TFDBatchMoveDataSetWriter ti consente di inserire i dati mantenendo i vecchi ID originali durante il processo di migrazione.

Date vuote ("00/00/0000"): BDE tollera date non valide, mentre Firebird rifiuterà il record. In RAD Studio 13.1 puoi intercettare l'evento OnGetText dei campi TDateField di Paradox per forzare il valore a NULL o a una data valida se viene rilevata una data corrotta.

Maiuscole/Minuscole: Firebird tratta i nomi delle tabelle e dei campi senza virgolette come maiuscoli. Assicurati che i nomi dei campi mappati corrispondano (il TFDBatchMove fa questo abbinamento per nome in modo automatico se le colonne hanno lo stesso nome).