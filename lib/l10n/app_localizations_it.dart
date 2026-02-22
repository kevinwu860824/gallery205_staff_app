// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get homeTitle => 'Gallery 20.5';

  @override
  String get loading => 'Caricamento...';

  @override
  String get homeOrder => 'Ordine';

  @override
  String get homeCalendar => 'Calendario';

  @override
  String get homeShift => 'Turno';

  @override
  String get homePrep => 'Preparazione';

  @override
  String get homeStock => 'Inventario';

  @override
  String get homeClockIn => 'Timbratura';

  @override
  String get homeWorkReport => 'Rapporto di Lavoro';

  @override
  String get homeBackhouse => 'Gestione';

  @override
  String get homeDailyCost => 'Costo Giornaliero';

  @override
  String get homeCashFlow => 'Flusso di Cassa';

  @override
  String get homeMonthlyCost => 'Costo Mensile';

  @override
  String get homeSetting => 'Impostazioni';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get defaultUser => 'Utente';

  @override
  String get settingPrepInfo => 'Info Preparazione';

  @override
  String get settingStock => 'Inventario';

  @override
  String get settingStockLog => 'Registro Inventario';

  @override
  String get settingTable => 'Tavolo';

  @override
  String get settingTableMap => 'Mappa Tavoli';

  @override
  String get settingMenu => 'Menu';

  @override
  String get settingPrinter => 'Stampante';

  @override
  String get settingClockInInfo => 'Info Timbratura';

  @override
  String get settingPayment => 'Pagamento';

  @override
  String get settingCashbox => 'Cassa';

  @override
  String get settingShift => 'Turni';

  @override
  String get settingUserManagement => 'Gestione Utenti';

  @override
  String get settingCostCategories => 'Categorie di Costo';

  @override
  String get settingLanguage => 'Lingua';

  @override
  String get settingChangePassword => 'Cambia Password';

  @override
  String get settingLogout => 'Esci';

  @override
  String get settingRoleManagement => 'Gestione Ruoli';

  @override
  String get loginTitle => 'Accesso';

  @override
  String get loginShopIdHint => 'Seleziona ID Negozio';

  @override
  String get loginEmailHint => 'Email';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginButton => 'Accedi';

  @override
  String get loginAddShopOption => '+ Aggiungi Negozio';

  @override
  String get loginAddShopDialogTitle => 'Aggiungi Negozio';

  @override
  String get loginAddShopDialogHint => 'Inserisci il codice del nuovo negozio';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonAdd => 'Aggiungi';

  @override
  String get loginMsgFillAll => 'Si prega di compilare tutti i campi';

  @override
  String get loginMsgFaceIdFirst => 'Si prega di accedere prima con l\'Email';

  @override
  String get loginMsgFaceIdReason => 'Si prega di utilizzare Face ID per accedere';

  @override
  String get loginMsgNoSavedData => 'Nessun dato di accesso salvato';

  @override
  String get loginMsgNoFaceIdData => 'Nessun dato Face ID trovato per questo account';

  @override
  String get loginMsgShopNotFound => 'Negozio non trovato';

  @override
  String get loginMsgNoPermission => 'Non si dispone dell\'autorizzazione per questo negozio';

  @override
  String get loginMsgFailed => 'Accesso fallito';

  @override
  String loginMsgFailedReason(Object error) {
    return 'Accesso fallito: $error';
  }

  @override
  String get scheduleTitle => 'Programmazione';

  @override
  String get scheduleTabMy => 'Miei';

  @override
  String get scheduleTabAll => 'Tutti';

  @override
  String get scheduleTabCustom => 'Personalizzato';

  @override
  String get scheduleFilterTooltip => 'Filtra Gruppi';

  @override
  String get scheduleSelectGroups => 'Seleziona Gruppi';

  @override
  String get commonDone => 'Fatto';

  @override
  String get schedulePersonalMe => 'Personale (Io)';

  @override
  String get scheduleUntitled => 'Senza Titolo';

  @override
  String get scheduleNoEvents => 'Nessun evento';

  @override
  String get scheduleAllDay => 'Tutto il giorno';

  @override
  String get scheduleDayLabel => 'Giorno';

  @override
  String get commonNoTitle => 'Senza Titolo';

  @override
  String scheduleMoreEvents(Object count) {
    return '+$count altro/i...';
  }

  @override
  String get commonToday => 'Oggi';

  @override
  String get calendarGroupsTitle => 'Gruppi Calendario';

  @override
  String get calendarGroupPersonal => 'Personale (Io)';

  @override
  String get calendarGroupUntitled => 'Senza Titolo';

  @override
  String get calendarGroupPrivateDesc => 'Eventi privati visibili solo a te';

  @override
  String calendarGroupVisibleToMembers(Object count) {
    return 'Visibile a $count membri';
  }

  @override
  String get calendarGroupNew => 'Nuovo Gruppo';

  @override
  String get calendarGroupEdit => 'Modifica Gruppo';

  @override
  String get calendarGroupName => 'NOME GRUPPO';

  @override
  String get calendarGroupNameHint => 'es. Lavoro, Riunione';

  @override
  String get calendarGroupColor => 'COLORE GRUPPO';

  @override
  String get calendarGroupEventColors => 'COLORI EVENTO';

  @override
  String get calendarGroupSaveFirstHint => 'Salva prima questo gruppo per impostare colori evento personalizzati.';

  @override
  String get calendarGroupVisibleTo => 'VISIBILE AI MEMBRI';

  @override
  String get calendarGroupDelete => 'Elimina Gruppo';

  @override
  String get calendarGroupDeleteConfirm => 'L\'eliminazione di questo gruppo rimuoverà tutti gli eventi associati. Sei sicuro?';

  @override
  String get calendarColorNew => 'Nuovo Colore';

  @override
  String get calendarColorEdit => 'Modifica Colore';

  @override
  String get calendarColorName => 'NOME COLORE';

  @override
  String get calendarColorNameHint => 'es. Urgente, Riunione';

  @override
  String get calendarColorPick => 'SCEGLI COLORE';

  @override
  String get calendarColorDelete => 'Elimina Colore';

  @override
  String get calendarColorDeleteConfirm => 'Eliminare questa impostazione colore?';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get notificationGroupInviteTitle => 'Invito al Gruppo';

  @override
  String notificationGroupInviteBody(Object groupName) {
    return 'Sei stato aggiunto al gruppo calendario: $groupName';
  }

  @override
  String get eventDetailTitleEdit => 'Modifica Evento';

  @override
  String get eventDetailTitleNew => 'Nuovo Evento';

  @override
  String get eventDetailLabelTitle => 'Titolo';

  @override
  String get eventDetailLabelGroup => 'Gruppo';

  @override
  String get eventDetailLabelColor => 'Colore';

  @override
  String get eventDetailLabelAllDay => 'Tutto il giorno';

  @override
  String get eventDetailLabelStarts => 'Inizia';

  @override
  String get eventDetailLabelEnds => 'Finisce';

  @override
  String get eventDetailLabelRepeat => 'Ripeti';

  @override
  String get eventDetailLabelRelatedPeople => 'Persone Correlate';

  @override
  String get eventDetailLabelNotes => 'Note';

  @override
  String get eventDetailDelete => 'Elimina Evento';

  @override
  String get eventDetailDeleteConfirm => 'Sei sicuro di voler eliminare questo evento?';

  @override
  String get eventDetailSelectGroup => 'Seleziona Gruppo';

  @override
  String get eventDetailSelectColor => 'Seleziona Colore';

  @override
  String get eventDetailGroupDefault => 'Predefinito del Gruppo';

  @override
  String get eventDetailCustomColor => 'Colore Personalizzato';

  @override
  String get eventDetailNoCustomColors => 'Nessun colore personalizzato impostato per questo gruppo.';

  @override
  String get eventDetailSelectPeople => 'Seleziona Persone';

  @override
  String eventDetailPeopleCount(Object count) {
    return '$count persone';
  }

  @override
  String get eventDetailNone => 'Nessuno';

  @override
  String get eventDetailRepeatNone => 'Nessuno';

  @override
  String get eventDetailRepeatDaily => 'Giornaliero';

  @override
  String get eventDetailRepeatWeekly => 'Settimanale';

  @override
  String get eventDetailRepeatMonthly => 'Mensile';

  @override
  String get eventDetailErrorTitleRequired => 'Il titolo è obbligatorio';

  @override
  String get eventDetailErrorGroupRequired => 'Il gruppo è obbligatorio';

  @override
  String get eventDetailErrorEndTime => 'L\'ora di fine non può essere precedente all\'ora di inizio';

  @override
  String get eventDetailErrorSave => 'Salvataggio evento fallito';

  @override
  String get eventDetailErrorDelete => 'Eliminazione fallita';

  @override
  String notificationNewEventTitle(Object groupName) {
    return '[$groupName] Nuovo Evento';
  }

  @override
  String notificationNewEventBody(Object time, Object title, Object userName) {
    return '$userName ha aggiunto: $title ($time)';
  }

  @override
  String get notificationTimeChangeTitle => '⏰ [Aggiornamento] Orario Modificato';

  @override
  String notificationTimeChangeBody(Object title, Object userName) {
    return '$userName ha cambiato l\'orario di \"$title\", si prega di verificare.';
  }

  @override
  String get notificationContentChangeTitle => '✏️ [Aggiornamento] Contenuto Modificato';

  @override
  String notificationContentChangeBody(Object title, Object userName) {
    return '$userName ha aggiornato i dettagli di \"$title\".';
  }

  @override
  String get notificationDeleteTitle => '🗑️ [Annulla] Evento Rimosso';

  @override
  String notificationDeleteBody(Object title, Object userName) {
    return '$userName ha annullato l\'evento: $title';
  }

  @override
  String get localNotificationTitle => '🔔 Promemoria';

  @override
  String localNotificationBody(Object title) {
    return 'Tra 10 minuti: $title';
  }

  @override
  String get commonSelect => 'Seleziona...';

  @override
  String get commonUnknown => 'Sconosciuto';

  @override
  String get commonPersonalMe => 'Personale (Io)';

  @override
  String get scheduleViewTitle => 'Programmazione Lavorativa';

  @override
  String get scheduleViewModeMy => 'Miei Turni';

  @override
  String get scheduleViewModeAll => 'Tutti i Turni';

  @override
  String scheduleViewErrorInit(Object error) {
    return 'Caricamento dati iniziali fallito: $error';
  }

  @override
  String scheduleViewErrorFetch(Object error) {
    return 'Recupero programma fallito: $error';
  }

  @override
  String get scheduleViewUnknown => 'Sconosciuto';

  @override
  String get scheduleUploadTitle => 'Assegnazione Turni';

  @override
  String get scheduleUploadSelectEmployee => 'Seleziona Dipendente';

  @override
  String get scheduleUploadSelectShiftFirst => 'Si prega di selezionare prima un tipo di turno sopra.';

  @override
  String get scheduleUploadUnsavedChanges => 'Modifiche non Salvate';

  @override
  String get scheduleUploadDiscardChangesMessage => 'Hai modifiche non salvate. Cambiando dipendente o uscendo, verranno scartate. Continuare?';

  @override
  String get scheduleUploadNoChanges => 'Nessuna modifica da salvare.';

  @override
  String get scheduleUploadSaveSuccess => 'Programma salvato!';

  @override
  String scheduleUploadSaveError(Object error) {
    return 'Salvataggio fallito: $error';
  }

  @override
  String scheduleUploadLoadError(Object error) {
    return 'Caricamento dati iniziali fallito: $error';
  }

  @override
  String scheduleUploadLoadScheduleError(Object name) {
    return 'Caricamento programma per $name fallito';
  }

  @override
  String scheduleUploadRole(Object role) {
    return 'Ruolo: $role';
  }

  @override
  String get commonConfirm => 'Conferma';

  @override
  String get commonSaveChanges => 'Salva Modifiche';

  @override
  String get prepViewTitle => 'Visualizza Categoria Preparazione';

  @override
  String get prepViewItemTitle => 'Visualizza Elemento Preparazione';

  @override
  String get prepViewItemUntitled => 'Elemento Senza Titolo';

  @override
  String get prepViewMainIngredients => 'Ingredienti Principali';

  @override
  String prepViewNote(Object note) {
    return 'Nota: $note';
  }

  @override
  String get prepViewDetailLabel => 'Dettaglio';

  @override
  String get settingCategoryPersonnel => 'Personnel & Permissions';

  @override
  String get settingCategoryMenuInv => 'Menu & Inventory';

  @override
  String get settingCategoryEquipTable => 'Equipment & Tables';

  @override
  String get settingCategorySystem => 'System';

  @override
  String get settingPayroll => 'Payroll Report';

  @override
  String get permBackPayroll => 'Payroll Report';

  @override
  String get permBackLoginWeb => 'Allow Backend Login';

  @override
  String get settingModifiers => 'Modifiers Setup';

  @override
  String get settingTax => 'Tax Settings';

  @override
  String get inventoryViewTitle => 'Panoramica Inventario';

  @override
  String get inventorySearchHint => 'Cerca Articolo';

  @override
  String get inventoryNoItems => 'Nessun articolo trovato';

  @override
  String inventorySafetyQuantity(Object quantity) {
    return 'Quantità di Sicurezza: $quantity';
  }

  @override
  String get inventoryConfirmUpdateTitle => 'Conferma Aggiornamento';

  @override
  String inventoryConfirmUpdateOriginal(Object unit, Object value) {
    return 'Numero Originale: $value $unit';
  }

  @override
  String inventoryConfirmUpdateNew(Object unit, Object value) {
    return 'Nuovo Numero: $value $unit';
  }

  @override
  String inventoryConfirmUpdateChange(Object value) {
    return 'Cambio: $value';
  }

  @override
  String get inventoryUnsavedTitle => 'Modifica non Salvata';

  @override
  String get inventoryUnsavedContent => 'Hai aggiustamenti di inventario non salvati. Vuoi salvare ed uscire?';

  @override
  String get inventoryUnsavedDiscard => 'Annulla & Esci';

  @override
  String inventoryUpdateSuccess(Object name) {
    return '✅ Scorte di $name aggiornate con successo!';
  }

  @override
  String get inventoryUpdateFailedTitle => 'Aggiornamento Fallito';

  @override
  String get inventoryUpdateFailedMsg => 'Errore database, si prega di contattare l\'amministratore.';

  @override
  String get inventoryBatchSaveFailedTitle => 'Salvataggio in Batch Fallito';

  @override
  String inventoryBatchSaveFailedMsg(Object name) {
    return 'Salvataggio articolo $name fallito.';
  }

  @override
  String get inventoryReasonStockIn => 'Carico Magazzino';

  @override
  String get inventoryReasonAudit => 'Aggiustamento Inventario';

  @override
  String get inventoryErrorTitle => 'Errore';

  @override
  String get inventoryErrorInvalidNumber => 'Si prega di inserire un numero valido';

  @override
  String get commonOk => 'OK';

  @override
  String get punchTitle => 'Timbratura';

  @override
  String get punchInButton => 'Ingresso';

  @override
  String get punchOutButton => 'Uscita';

  @override
  String get punchMakeUpButton => 'Compensa\nIngresso/Uscita';

  @override
  String get punchLocDisabled => 'Servizi di localizzazione disabilitati. Abilitali nelle Impostazioni.';

  @override
  String get punchLocDenied => 'Permessi di localizzazione negati';

  @override
  String get punchLocDeniedForever => 'Permessi di localizzazione permanentemente negati, non possiamo richiedere i permessi.';

  @override
  String get punchErrorSettingsNotFound => 'Impostazioni timbratura negozio non trovate. Si prega di contattare il manager.';

  @override
  String punchErrorWifi(Object wifi) {
    return 'Wi-Fi errato.\nSi prega di connettersi a: $wifi';
  }

  @override
  String get punchErrorDistance => 'Sei troppo lontano dal negozio.';

  @override
  String get punchErrorAlreadyIn => 'Hai già timbrato l\'ingresso.';

  @override
  String get punchSuccessInTitle => 'Timbratura Ingresso Riuscita';

  @override
  String get punchSuccessInMsg => 'Buon turno : )';

  @override
  String get punchErrorInTitle => 'Timbratura Ingresso Fallita';

  @override
  String get punchErrorNoSession => 'Nessuna sessione attiva trovata entro 24 ore. Si prega di contattare il manager.';

  @override
  String get punchErrorOverTime => 'Oltre 12 ore. Si prega di utilizzare la funzione \"Compensa\".';

  @override
  String get punchSuccessOutTitle => 'Timbratura Uscita Riuscita';

  @override
  String get punchSuccessOutMsg => 'Il capo ti vuole bene ❤️';

  @override
  String get punchErrorOutTitle => 'Timbratura Uscita Fallita';

  @override
  String punchErrorGeneric(Object error) {
    return 'Si è verificato un errore: $error';
  }

  @override
  String get punchMakeUpTitle => 'Compensa Timbratura Ingresso/Uscita';

  @override
  String get punchMakeUpTypeIn => 'Compensa Ingresso';

  @override
  String get punchMakeUpTypeOut => 'Compensa Uscita';

  @override
  String get punchMakeUpReasonHint => 'Motivo (Obbligatorio)';

  @override
  String get punchMakeUpErrorReason => 'Si prega di compilare il motivo';

  @override
  String get punchMakeUpErrorFuture => 'Non è possibile compensare un orario futuro';

  @override
  String get punchMakeUpError72h => 'Non è possibile compensare oltre 72 ore. Si prega di contattare il manager.';

  @override
  String punchMakeUpErrorOverlap(Object time) {
    return 'Sessione attiva trovata alle $time. Si prega di timbrare l\'uscita prima.';
  }

  @override
  String get punchMakeUpErrorNoRecord => 'Nessun record corrispondente trovato entro 72 ore. Si prega di contattare il manager.';

  @override
  String get punchMakeUpErrorOver12h => 'La durata del turno supera le 12 ore. Si prega di contattare il manager.';

  @override
  String get punchMakeUpSuccessTitle => 'Riuscito';

  @override
  String get punchMakeUpSuccessMsg => 'La tua compensazione di timbratura ingresso/uscita è riuscita';

  @override
  String get punchMakeUpCheckInfo => 'Si prega di Verificare le Informazioni';

  @override
  String punchMakeUpLabelType(Object type) {
    return 'Tipo: $type';
  }

  @override
  String punchMakeUpLabelTime(Object time) {
    return 'Ora: $time';
  }

  @override
  String punchMakeUpLabelReason(Object reason) {
    return 'Motivo: $reason';
  }

  @override
  String get commonDate => 'Data';

  @override
  String get commonTime => 'Ora';

  @override
  String get workReportTitle => 'Rapporto di Lavoro';

  @override
  String get workReportSelectDate => 'Seleziona Data';

  @override
  String get workReportJobSubject => 'Oggetto Lavoro (Obbligatorio)';

  @override
  String get workReportJobDescription => 'Descrizione Lavoro (Obbligatoria)';

  @override
  String get workReportOverTime => 'Ore di straordinario (Opzionale)';

  @override
  String get workReportHourUnit => 'ore';

  @override
  String get workReportErrorRequiredTitle => 'Si Prega di Compilare I\nCampi Obbligatori';

  @override
  String get workReportErrorRequiredMsg => 'Oggetto e Descrizione\nsono obbligatori!';

  @override
  String get workReportConfirmOverwriteTitle => 'Rapporto Esistente';

  @override
  String get workReportConfirmOverwriteMsg => 'Hai già inviato\nun rapporto per questa data.\nVuoi sovrascriverlo?';

  @override
  String get workReportOverwriteYes => 'Sì';

  @override
  String get workReportSuccessTitle => 'Riuscito';

  @override
  String get workReportSuccessMsg => 'Il tuo rapporto di lavoro è stato inviato con successo!';

  @override
  String get workReportSubmitFailed => 'Invio Fallito';

  @override
  String get todoScreenTitle => 'Lista delle Cose da Fare';

  @override
  String get todoTabIncomplete => 'Incompleto';

  @override
  String get todoTabPending => 'In Sospeso';

  @override
  String get todoTabCompleted => 'Completato';

  @override
  String get todoFilterMyTasks => 'Solo i Miei Compiti';

  @override
  String todoCountSuffix(Object count) {
    return '$count elementi';
  }

  @override
  String get todoEmptyPending => 'Nessun compito in sospeso';

  @override
  String get todoEmptyIncomplete => 'Nessun compito incompleto';

  @override
  String get todoEmptyCompleted => 'Nessun compito completato questo mese';

  @override
  String get todoSubmitReviewTitle => 'Invia per Revisione';

  @override
  String get todoSubmitReviewContent => 'Sei sicuro di aver completato questo compito e di volerlo inviare per la revisione?';

  @override
  String get todoSubmitButton => 'Invia';

  @override
  String get todoApproveTitle => 'Approva Compito';

  @override
  String get todoApproveContent => 'Sei sicuro che questo compito sia completato?';

  @override
  String get todoApproveButton => 'Approva';

  @override
  String get todoRejectTitle => 'Rifiuta Compito';

  @override
  String get todoRejectContent => 'Restituire questo compito al dipendente per la rielaborazione?';

  @override
  String get todoRejectButton => 'Restituisci';

  @override
  String get todoDeleteTitle => 'Elimina Compito';

  @override
  String get todoDeleteContent => 'Sei sicuro? Questa azione non può essere annullata.';

  @override
  String get todoErrorNoPermissionSubmit => 'Non hai il permesso di inviare questo compito.';

  @override
  String get todoErrorNoPermissionApprove => 'Solo l\'assegnatore può approvare questo compito.';

  @override
  String get todoErrorNoPermissionReject => 'Solo l\'assegnatore può rifiutare questo compito.';

  @override
  String get todoErrorNoPermissionEdit => 'Solo l\'assegnatore può modificare questo compito.';

  @override
  String get todoErrorNoPermissionDelete => 'Solo l\'assegnatore può eliminare questo compito.';

  @override
  String get notificationTodoReviewTitle => '👀 Compito da Revisionare';

  @override
  String notificationTodoReviewBody(Object name, Object task) {
    return '$name ha inviato: $task, si prega di verificare.';
  }

  @override
  String get notificationTodoApprovedTitle => '✅ Compito Approvato';

  @override
  String notificationTodoApprovedBody(Object task) {
    return 'Assegnatore ha approvato: $task';
  }

  @override
  String get notificationTodoRejectedTitle => '↩️ Compito Restituito';

  @override
  String notificationTodoRejectedBody(Object task) {
    return 'Si prega di rivedere e inviare nuovamente: $task';
  }

  @override
  String get notificationTodoDeletedTitle => '🗑️ Compito Eliminato';

  @override
  String notificationTodoDeletedBody(Object task) {
    return 'Assegnatore ha eliminato: $task';
  }

  @override
  String todoActionSheetTitle(Object title) {
    return 'Azione: $title';
  }

  @override
  String get todoActionCompleteAndSubmit => 'Completa e Invia';

  @override
  String todoReviewSheetTitle(Object title) {
    return 'Revisione: $title';
  }

  @override
  String get todoReviewSheetMessageAssigner => 'Si prega di confermare se il compito è qualificato.';

  @override
  String get todoReviewSheetMessageAssignee => 'In attesa di revisione dell\'assegnatore.';

  @override
  String get todoActionApprove => '✅ Approva';

  @override
  String get todoActionReject => '↩️ Restituisci';

  @override
  String get todoActionViewDetails => 'Visualizza Dettagli';

  @override
  String get todoLabelTo => 'A: ';

  @override
  String get todoLabelFrom => 'Da: ';

  @override
  String get todoUnassigned => 'Non Assegnato';

  @override
  String get todoLabelCompletedAt => 'Completato: ';

  @override
  String get todoLabelWaitingReview => 'In Attesa di Revisione';

  @override
  String get commonEdit => 'Modifica';

  @override
  String get todoAddTaskTitleNew => 'Nuovo Compito';

  @override
  String get todoAddTaskTitleEdit => 'Modifica Compito';

  @override
  String get todoAddTaskLabelTitle => 'Titolo Compito';

  @override
  String get todoAddTaskLabelDesc => 'Descrizione (Opzionale)';

  @override
  String get todoAddTaskLabelAssign => 'Assegna A:';

  @override
  String get todoAddTaskSelectStaff => 'Seleziona Personale';

  @override
  String todoAddTaskSelectedStaff(Object count) {
    return '$count Personale Selezionato';
  }

  @override
  String get todoAddTaskSetDueDate => 'Imposta Data di Scadenza';

  @override
  String get todoAddTaskSelectDate => 'Seleziona Data';

  @override
  String get todoAddTaskSetDueTime => 'Imposta Ora di Scadenza';

  @override
  String get todoAddTaskSelectTime => 'Seleziona Ora';

  @override
  String get notificationTodoEditTitle => '✏️ Compito Aggiornato';

  @override
  String notificationTodoEditBody(Object task) {
    return 'Contenuto aggiornato: $task';
  }

  @override
  String get notificationTodoUrgentUpdate => '🔥 Aggiornamento Urgente';

  @override
  String get notificationTodoNewTitle => '📝 Nuovo Compito';

  @override
  String notificationTodoNewBody(Object task) {
    return '$task';
  }

  @override
  String get notificationTodoUrgentNew => '🔥 Compito Urgente';

  @override
  String get costInputTitle => 'Costo Giornaliero';

  @override
  String get costInputTotalToday => 'Costo totale di oggi';

  @override
  String get costInputLabelName => 'Nome';

  @override
  String get costInputLabelPrice => 'Prezzo';

  @override
  String get costInputTabNotOpenTitle => 'La scheda non è aperta';

  @override
  String get costInputTabNotOpenMsg => 'Si prega di aprire prima la scheda di oggi.';

  @override
  String get costInputTabNotOpenPageTitle => 'Si Prega di Aprire La Scheda di Oggi';

  @override
  String get costInputTabNotOpenPageDesc => 'È necessario aprire la scheda prima di\npoter iniziare a compilare i costi giornalieri.';

  @override
  String get costInputButtonOpenTab => 'Vai ad Aprire La Scheda di Oggi';

  @override
  String get costInputErrorInputTitle => 'Errore di Input';

  @override
  String get costInputErrorInputMsg => 'Si prega di assicurarsi che l\'articolo e il prezzo siano compilati correttamente.';

  @override
  String get costInputSuccess => '✅ Costo salvato con successo';

  @override
  String get costInputSaveFailed => 'Salvataggio Fallito';

  @override
  String get costInputLoadingCategories => 'Caricamento...';

  @override
  String get costDetailTitle => 'Dettaglio Costo Giornaliero';

  @override
  String get costDetailNoRecords => 'Nessun record di costo per questo periodo.';

  @override
  String get costDetailItemUntitled => 'Nessun Nome Articolo';

  @override
  String get costDetailCategoryNA => 'N/D';

  @override
  String get costDetailBuyerNA => 'N/D';

  @override
  String costDetailLabelCategory(Object category) {
    return 'Categoria: $category';
  }

  @override
  String costDetailLabelBuyer(Object buyer) {
    return 'Acquirente: $buyer';
  }

  @override
  String get costDetailEditTitle => 'Modifica Dettaglio Costo Giornaliero';

  @override
  String get costDetailDeleteTitle => 'Elimina Costo';

  @override
  String costDetailDeleteContent(Object name) {
    return 'Sei sicuro di voler eliminare questo costo?\n($name)';
  }

  @override
  String get costDetailErrorUpdate => 'Aggiornamento Fallito';

  @override
  String get costDetailErrorDelete => 'Eliminazione Fallita';

  @override
  String get cashSettlementDeposits => 'Deposits';

  @override
  String get cashSettlementExpectedCash => 'Expected Cash';

  @override
  String get cashSettlementDifference => 'Difference';

  @override
  String get cashSettlementConfirmTitle => 'Confirm Settlement';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get cashSettlementDepositSheetTitle => 'Deposit Sheet';

  @override
  String get cashSettlementDepositNew => 'New Deposit';

  @override
  String get cashSettlementNewDepositTitle => 'New Deposit';

  @override
  String get commonName => 'Name';

  @override
  String get commonPhone => 'Phone';

  @override
  String get commonAmount => 'Amount';

  @override
  String get commonNotes => 'Notes';

  @override
  String get cashSettlementDepositAddSuccess => 'Deposit Added Successfully';

  @override
  String get cashSettlementSelectRedeemedDeposit => 'Select Redeemed Deposit';

  @override
  String get commonNoData => 'No Data';

  @override
  String get cashSettlementTitleOpen => 'Verifica Apertura';

  @override
  String get cashSettlementTitleClose => 'Verifica Chiusura';

  @override
  String get cashSettlementTitleLoading => 'Caricamento...';

  @override
  String get cashSettlementOpenDesc => 'Si prega di verificare e confermare che il numero di banconote e l\'importo totale siano coerenti con i valori attesi.';

  @override
  String get cashSettlementTargetAmount => 'Importo target:';

  @override
  String get cashSettlementTotal => 'Totale:';

  @override
  String get cashSettlementRevenueAndPayment => 'Entrate Giornaliere e Metodi di Pagamento';

  @override
  String get cashSettlementRevenueHint => 'Entrate Totali';

  @override
  String cashSettlementDepositButton(Object amount) {
    return 'Deposito di Oggi (Selezionato: \$$amount)';
  }

  @override
  String get cashSettlementReceivableCash => 'Contante Incassabile:';

  @override
  String get cashSettlementCashCountingTitle => 'Conteggio Contanti\n(Si prega di Inserire il Numero Effettivo di Banconote)';

  @override
  String get cashSettlementTotalCashCounted => 'Totale Contante Contato:';

  @override
  String get cashSettlementReviewTitle => 'Revisione';

  @override
  String get cashSettlementOpeningCash => 'Contante di Apertura';

  @override
  String get cashSettlementDailyCosts => 'Costi Giornalieri';

  @override
  String get cashSettlementRedeemedDeposit => 'Deposito Riscattato';

  @override
  String get cashSettlementTotalExpectedCash => 'Totale Contante Previsto';

  @override
  String get cashSettlementTodaysCashCount => 'Conteggio Contante di Oggi';

  @override
  String get cashSettlementSummary => 'Riepilogo:';

  @override
  String get cashSettlementErrorCountMismatch => 'Il totale contato non corrisponde all\'importo target!';

  @override
  String get cashSettlementOpenSuccessTitle => 'Aperto con Successo';

  @override
  String cashSettlementOpenSuccessMsg(Object count) {
    return 'Turno $count aperto con successo!';
  }

  @override
  String get cashSettlementOpenFailedTitle => 'Apertura Fallita';

  @override
  String get cashSettlementCloseSuccessTitle => 'Chiuso & Salvato con Successo';

  @override
  String get cashSettlementCloseSuccessMsg => 'I capi ❤️ Te!';

  @override
  String get cashSettlementCloseFailedTitle => 'Chiusura Fallita';

  @override
  String get cashSettlementErrorInputRevenue => 'Si prega di inserire le entrate totali.';

  @override
  String get cashSettlementDepositTitle => 'Gestione Depositi';

  @override
  String get cashSettlementDepositAdd => 'Aggiungi Nuovo Deposito';

  @override
  String get cashSettlementDepositEdit => 'Modifica Tutti i Depositi';

  @override
  String get cashSettlementDepositRedeemTitle => 'Riscatta Deposito di Oggi';

  @override
  String get cashSettlementDepositNoUnredeemed => 'Nessun deposito non riscattato';

  @override
  String cashSettlementDepositTotalRedeemed(Object amount) {
    return 'Totale Riscattato: \$$amount';
  }

  @override
  String get cashSettlementDepositAddTitle => 'Aggiungi Deposito';

  @override
  String get cashSettlementDepositEditTitle => 'Modifica Deposito';

  @override
  String get cashSettlementDepositPaymentDate => 'Data Pagamento';

  @override
  String get cashSettlementDepositReservationDate => 'Data Prenotazione';

  @override
  String get cashSettlementDepositReservationTime => 'Ora Prenotazione';

  @override
  String get cashSettlementDepositName => 'Nome';

  @override
  String get cashSettlementDepositPax => 'Numero di Persone';

  @override
  String get cashSettlementDepositAmount => 'Importo Deposito';

  @override
  String get cashSettlementErrorInputDates => 'Si prega di selezionare tutte le date e gli orari.';

  @override
  String get cashSettlementErrorInputAmount => 'Si prega di compilare il nome e l\'importo valido';

  @override
  String get cashSettlementErrorTimePast => 'L\'orario di prenotazione non può essere nel passato';

  @override
  String get cashSettlementSaveFailed => 'Salvataggio Fallito';

  @override
  String get depositScreenTitle => 'Gestione Depositi';

  @override
  String get depositScreenNoRecords => 'Nessun deposito non riscattato';

  @override
  String depositScreenLabelName(Object name) {
    return 'Nome: $name';
  }

  @override
  String depositScreenLabelReservationDate(Object date) {
    return 'Data Prenotazione: $date';
  }

  @override
  String depositScreenLabelReservationTime(Object time) {
    return 'Ora Prenotazione: $time';
  }

  @override
  String depositScreenLabelGroupSize(Object size) {
    return 'Dimensione Gruppo: $size';
  }

  @override
  String get depositScreenDeleteConfirm => 'Elimina Deposito';

  @override
  String get depositScreenDeleteContent => 'Sei sicuro di voler eliminare questo deposito?';

  @override
  String get depositScreenDeleteSuccess => 'Deposito eliminato';

  @override
  String depositScreenDeleteFailed(Object error) {
    return 'Eliminazione fallita: $error';
  }

  @override
  String depositScreenSaveFailed(Object error) {
    return 'Salvataggio fallito: $error';
  }

  @override
  String get depositScreenInputError => 'Si prega di compilare tutti i campi obbligatori (Nome, Importo, Data/Ora).';

  @override
  String get depositScreenTimeError => 'L\'orario di prenotazione non può essere nel passato.';

  @override
  String get depositDialogTitleAdd => 'Aggiungi Deposito';

  @override
  String get depositDialogTitleEdit => 'Modifica Deposito';

  @override
  String get depositDialogHintPaymentDate => 'Data Pagamento';

  @override
  String get depositDialogHintReservationDate => 'Data Prenotazione';

  @override
  String get depositDialogHintReservationTime => 'Ora Prenotazione';

  @override
  String get depositDialogHintName => 'Nome';

  @override
  String get depositDialogHintGroupSize => 'Dimensione Gruppo';

  @override
  String get depositDialogHintAmount => 'Importo Deposito';

  @override
  String get monthlyCostTitle => 'Costo Mensile';

  @override
  String get monthlyCostTotal => 'Costo totale di questo mese';

  @override
  String get monthlyCostLabelName => 'Nome';

  @override
  String get monthlyCostLabelPrice => 'Prezzo';

  @override
  String get monthlyCostLabelNote => 'Nota';

  @override
  String get monthlyCostErrorInputTitle => 'Errore';

  @override
  String get monthlyCostErrorInputMsg => 'Nome e Prezzo sono obbligatori.';

  @override
  String get monthlyCostErrorSaveFailed => 'Salvataggio Fallito';

  @override
  String get monthlyCostSuccess => 'Costo salvato con successo';

  @override
  String get monthlyCostDetailTitle => 'Dettaglio Costo Mensile';

  @override
  String get monthlyCostDetailNoRecords => 'Nessun record di costo per questo mese.';

  @override
  String get monthlyCostDetailItemUntitled => 'Nessun Nome Articolo';

  @override
  String get monthlyCostDetailCategoryNA => 'N/D';

  @override
  String get monthlyCostDetailBuyerNA => 'N/D';

  @override
  String monthlyCostDetailLabelCategory(Object category) {
    return 'Categoria: $category';
  }

  @override
  String monthlyCostDetailLabelDate(Object date) {
    return 'Data: $date';
  }

  @override
  String monthlyCostDetailLabelBuyer(Object buyer) {
    return 'Acquirente: $buyer';
  }

  @override
  String get monthlyCostDetailEditTitle => 'Modifica Dettaglio Costo Mensile';

  @override
  String get monthlyCostDetailDeleteTitle => 'Elimina Costo';

  @override
  String monthlyCostDetailDeleteContent(Object name) {
    return 'Sei sicuro di voler eliminare questo costo?\n($name)';
  }

  @override
  String monthlyCostDetailErrorFetch(Object error) {
    return 'Recupero spese fallito: $error';
  }

  @override
  String get monthlyCostDetailErrorUpdate => 'Aggiornamento Fallito';

  @override
  String get monthlyCostDetailErrorDelete => 'Eliminazione Fallita';

  @override
  String get cashFlowTitle => 'Rapporto Flusso di Cassa';

  @override
  String get cashFlowMonthlyRevenue => 'Entrate Mensili';

  @override
  String get cashFlowMonthlyDifference => 'Differenza Mensile';

  @override
  String cashFlowLabelShift(Object count) {
    return 'Turno $count';
  }

  @override
  String get cashFlowLabelRevenue => 'Entrate Totali:';

  @override
  String get cashFlowLabelCost => 'Costo Totale:';

  @override
  String get cashFlowLabelDifference => 'Differenza Cassa:';

  @override
  String get cashFlowNoRecords => 'Nessun record trovato.';

  @override
  String get costReportTitle => 'Riepilogo Costi';

  @override
  String get costReportMonthlyTotal => 'Totale Costo Mensile';

  @override
  String get costReportNoRecords => 'Nessun record di costo.';

  @override
  String get costReportNoRecordsShift => 'Nessun record di costo per questo turno.';

  @override
  String get costReportLabelTotalCost => 'Costo Totale:';

  @override
  String get dashboardTitle => 'Pannello Operativo';

  @override
  String get dashboardTotalRevenue => 'Entrate Totali';

  @override
  String get dashboardCogs => 'Costo del Venduto';

  @override
  String get dashboardGrossProfit => 'Profitto Lordo';

  @override
  String get dashboardGrossMargin => 'Margine Lordo';

  @override
  String get dashboardOpex => 'Spese Operative';

  @override
  String get dashboardOpIncome => 'Reddito Operativo';

  @override
  String get dashboardNetIncome => 'Reddito Netto';

  @override
  String get dashboardNetProfitMargin => 'Margine di Profitto Netto';

  @override
  String get dashboardNoCostData => 'Nessun dato di costo disponibile';

  @override
  String dashboardErrorLoad(Object error) {
    return 'Errore di caricamento dati: $error';
  }

  @override
  String get reportingTitle => 'Backstage';

  @override
  String get reportingCashFlow => 'Flusso di Cassa';

  @override
  String get reportingCostSum => 'Somma Costi';

  @override
  String get reportingDashboard => 'Pannello';

  @override
  String get reportingCashVault => 'Cassaforte Contanti';

  @override
  String get reportingClockIn => 'Timbratura';

  @override
  String get reportingWorkReport => 'Rapporto di Lavoro';

  @override
  String get reportingNoAccess => 'Nessuna funzione accessibile';

  @override
  String get vaultTitle => 'Flusso di Cassa';

  @override
  String get vaultTotalCash => 'Totale Contanti';

  @override
  String get vaultTitleVault => 'Cassaforte';

  @override
  String get vaultTitleCashbox => 'Cassa';

  @override
  String get vaultCashDetail => 'Dettaglio Contanti';

  @override
  String vaultDetailDenom(Object cashboxCount, Object totalCount, Object vaultCount) {
    return '\$ $cashboxCount X $totalCount (Cassaforte $cashboxCount + Cassa $vaultCount)';
  }

  @override
  String get vaultActivityHistory => 'Cronologia Attività';

  @override
  String get vaultTableDate => 'Data';

  @override
  String get vaultTableStaff => 'Personale';

  @override
  String get vaultNoRecords => 'Nessun record di attività.';

  @override
  String get vaultManagementSheetTitle => 'Gestione Cassaforte';

  @override
  String get vaultAdjustCounts => 'Regola Conteggi Cassaforte';

  @override
  String get vaultSaveMoney => 'Deposita Denaro (Deposito)';

  @override
  String get vaultChangeMoney => 'Cambia Denaro';

  @override
  String get vaultPromptAdjust => 'Inserisci i conteggi TOTALI (Cassaforte + Cassa).';

  @override
  String get vaultPromptDeposit => 'Inserisci l\'importo da depositare in banca';

  @override
  String get vaultPromptChangeOut => 'PRELEVA banconote grandi dalla Cassaforte';

  @override
  String get vaultPromptChangeIn => 'INSERISCI banconote piccole nella Cassaforte';

  @override
  String get vaultErrorMismatch => 'Importo non corrispondente! Scambio annullato.';

  @override
  String vaultDialogTotal(Object amount) {
    return 'Totale: $amount';
  }

  @override
  String get clockInReportTitle => 'Rapporto Timbrature';

  @override
  String get clockInReportTotalHours => 'Ore Totali';

  @override
  String get clockInReportStaffCount => 'Numero Dipendenti';

  @override
  String get clockInReportWorkDays => 'Giorni Lavorativi';

  @override
  String get clockInReportUnitPpl => 'persone';

  @override
  String get clockInReportUnitDays => 'giorni';

  @override
  String get clockInReportUnitHr => 'ore';

  @override
  String get clockInReportNoRecords => 'Nessun record trovato.';

  @override
  String get clockInReportLabelManual => 'Manuale';

  @override
  String get clockInReportLabelIn => 'Ingresso';

  @override
  String get clockInReportLabelOut => 'Uscita';

  @override
  String get clockInReportStatusWorking => 'Lavorando';

  @override
  String get clockInReportStatusCompleted => 'Completato';

  @override
  String get clockInReportStatusIncomplete => 'Incompleto';

  @override
  String get clockInReportAllStaff => 'Tutto il Personale';

  @override
  String get clockInReportSelectStaff => 'Seleziona Personale';

  @override
  String get clockInDetailTitleIn => 'Ingresso';

  @override
  String get clockInDetailTitleOut => 'Uscita';

  @override
  String get clockInDetailMissing => 'Record Mancante';

  @override
  String get clockInDetailFixButton => 'Correggi Uscita';

  @override
  String get clockInDetailCloseButton => 'Chiudi';

  @override
  String clockInDetailLabelWifi(Object wifi) {
    return 'WiFi: $wifi';
  }

  @override
  String clockInDetailLabelReason(Object reason) {
    return 'Motivo: $reason';
  }

  @override
  String get clockInDetailReasonSupervisorFix => 'Correzione Supervisore';

  @override
  String get clockInDetailErrorInLaterThanOut => 'L\'ingresso non può essere successivo all\'uscita.';

  @override
  String get clockInDetailErrorOutEarlierThanIn => 'L\'uscita non può essere precedente all\'ingresso.';

  @override
  String get clockInDetailErrorDateCheck => 'Errore Data: Si prega di verificare di aver selezionato la data corretta (es. giorno successivo).';

  @override
  String get clockInDetailSuccessUpdate => 'Ora aggiornata con successo.';

  @override
  String get clockInDetailSelectDate => 'Seleziona Data Uscita';

  @override
  String get commonNone => 'Nessuno';

  @override
  String get workReportOverviewTitle => 'Rapporti di Lavoro';

  @override
  String get workReportOverviewNoRecords => 'Nessun rapporto trovato.';

  @override
  String get workReportOverviewSelectStaff => 'Seleziona Personale';

  @override
  String get workReportOverviewAllStaff => 'Tutto il Personale';

  @override
  String get workReportOverviewNoSubject => 'Nessun Oggetto';

  @override
  String get workReportOverviewNoContent => 'Nessun Contenuto';

  @override
  String workReportOverviewOvertimeTag(Object hours) {
    return 'Straordinario: ${hours}h';
  }

  @override
  String workReportDetailOvertimeLabel(Object hours) {
    return 'Straordinario: $hours ore';
  }

  @override
  String get commonClose => 'Chiudi';

  @override
  String get userMgmtTitle => 'Gestione Utenti';

  @override
  String get userMgmtInviteNewUser => 'Invita Nuovo Utente';

  @override
  String get userMgmtStatusInvited => 'Invitato';

  @override
  String get userMgmtStatusWaiting => 'In Attesa...';

  @override
  String userMgmtLabelRole(Object roleName) {
    return 'Ruolo: $roleName';
  }

  @override
  String get userMgmtNameHint => 'Nome';

  @override
  String get userMgmtInviteNote => 'L\'utente riceverà un invito via email.';

  @override
  String get userMgmtInviteButton => 'Invita';

  @override
  String get userMgmtEditTitle => 'Modifica Info Utente';

  @override
  String get userMgmtDeleteTitle => 'Elimina Utente';

  @override
  String userMgmtDeleteContent(Object userName) {
    return 'Sei sicuro di voler eliminare $userName?';
  }

  @override
  String userMgmtErrorLoad(Object error) {
    return 'Caricamento fallito: $error';
  }

  @override
  String get userMgmtInviteSuccess => 'Invito inviato! L\'utente riceverà un\'email per unirsi.';

  @override
  String userMgmtInviteFailed(Object error) {
    return 'Invito fallito: $error';
  }

  @override
  String userMgmtErrorConnection(Object error) {
    return 'Errore di connessione: $error';
  }

  @override
  String userMgmtDeleteFailed(Object error) {
    return 'Eliminazione fallita: $error';
  }

  @override
  String get userMgmtLabelEmail => 'Email';

  @override
  String get userMgmtLabelRolePicker => 'Ruolo';

  @override
  String get userMgmtButtonDone => 'Fatto';

  @override
  String get userMgmtLabelRoleSelect => 'Seleziona';

  @override
  String get roleMgmtTitle => 'Gestione Ruoli';

  @override
  String get roleMgmtSystemDefault => 'Predefinito di Sistema';

  @override
  String roleMgmtPermissionGroupTitle(Object groupName) {
    return 'Permessi - $groupName';
  }

  @override
  String get roleMgmtRoleNameHint => 'Nome Ruolo';

  @override
  String get roleMgmtSaveButton => 'Salva';

  @override
  String get roleMgmtDeleteRole => 'Elimina Ruolo';

  @override
  String get roleMgmtAddNewRole => 'Aggiungi Nuovo Ruolo';

  @override
  String get roleMgmtEnterRoleName => 'Inserisci nome ruolo (es. Cameriere)';

  @override
  String get roleMgmtCreateButton => 'Crea';

  @override
  String get roleMgmtDeleteConfirmTitle => 'Elimina Ruolo';

  @override
  String get roleMgmtDeleteConfirmContent => 'Sei sicuro di voler eliminare questo ruolo? Questa azione non può essere annullata.';

  @override
  String get roleMgmtCannotDeleteTitle => 'Impossibile Eliminare Ruolo';

  @override
  String roleMgmtCannotDeleteContent(Object count, Object roleName) {
    return 'Ci sono ancora $count utenti assegnati al ruolo \"$roleName\".\n\nSi prega di assegnarli a un ruolo diverso prima di eliminare.';
  }

  @override
  String get roleMgmtUnderstandButton => 'Capisco';

  @override
  String roleMgmtErrorLoad(Object error) {
    return 'Caricamento ruoli fallito: $error';
  }

  @override
  String roleMgmtErrorSave(Object error) {
    return 'Errore salvataggio permessi: $error';
  }

  @override
  String roleMgmtErrorAdd(Object error) {
    return 'Errore aggiunta ruolo: $error';
  }

  @override
  String get commonNotificationTitle => 'Notifica';

  @override
  String get permGroupMainScreen => 'Schermata Principale';

  @override
  String get permGroupSchedule => 'Programmazione';

  @override
  String get permGroupBackstageDashboard => 'Pannello Gestione';

  @override
  String get permGroupSettings => 'Impostazioni';

  @override
  String get permHomeOrder => 'Prendi Ordini';

  @override
  String get permHomePrep => 'Lista Preparazione';

  @override
  String get permHomeStock => 'Inventario/Scorte';

  @override
  String get permHomeBackDashboard => 'Pannello Gestione';

  @override
  String get permHomeDailyCost => 'Inserimento Costo Giornaliero';

  @override
  String get permHomeCashFlow => 'Rapporto Flusso di Cassa';

  @override
  String get permHomeMonthlyCost => 'Inserimento Costo Mensile';

  @override
  String get permHomeScan => 'Scansione Intelligente';

  @override
  String get permScheduleEdit => 'Modifica Programmazione Personale';

  @override
  String get permBackCashFlow => 'Rapporto Flusso di Cassa';

  @override
  String get permBackCostSum => 'Rapporto Somma Costi';

  @override
  String get permBackDashboard => 'Pannello Operativo';

  @override
  String get permBackCashVault => 'Gestione Cassaforte Contanti';

  @override
  String get permBackClockIn => 'Rapporto Timbrature';

  @override
  String get permBackViewAllClockIn => 'Visualizza Tutte le Timbrature del Personale';

  @override
  String get permBackWorkReport => 'Panoramica Rapporti di Lavoro';

  @override
  String get permSetStaff => 'Gestisci Utenti';

  @override
  String get permSetRole => 'Gestione Ruoli';

  @override
  String get permSetPrinter => 'Impostazioni Stampante';

  @override
  String get permSetTableMap => 'Gestione Mappa Tavoli';

  @override
  String get permSetTableList => 'Lista Stato Tavoli';

  @override
  String get permSetMenu => 'Modifica Menu';

  @override
  String get permSetShift => 'Impostazioni Turni';

  @override
  String get permSetPunch => 'Impostazioni Timbratura';

  @override
  String get permSetPay => 'Metodi di Pagamento';

  @override
  String get permSetCostCat => 'Impostazioni Categoria di Costo';

  @override
  String get permSetInv => 'Inventario & Articoli';

  @override
  String get permSetCashReg => 'Impostazioni Cassa';

  @override
  String get stockCategoryTitle => 'Modifica Dettagli Preparazione';

  @override
  String get stockCategoryAddButton => '＋ Aggiungi Nuova Categoria';

  @override
  String get stockCategoryAddDialogTitle => 'Aggiungi Nuova Categoria';

  @override
  String get stockCategoryEditDialogTitle => 'Modifica Categoria';

  @override
  String get stockCategoryHintName => 'Nome Categoria';

  @override
  String get stockCategoryDeleteTitle => 'Elimina Categoria';

  @override
  String stockCategoryDeleteContent(Object categoryName) {
    return 'Sei sicuro di voler eliminare la Categoria: $categoryName?';
  }

  @override
  String get inventoryCategoryTitle => 'Modifica Lista Inventario';

  @override
  String get inventoryManagementTitle => 'Inventory Management';

  @override
  String get inventoryCategoryDetailTitle => 'Lista Prodotti';

  @override
  String get inventoryCategoryAddButton => '＋ Aggiungi Nuova Categoria';

  @override
  String get inventoryCategoryAddDialogTitle => 'Aggiungi Nuova Categoria';

  @override
  String get inventoryCategoryEditDialogTitle => 'Modifica Categoria';

  @override
  String get inventoryCategoryHintName => 'Nome Categoria';

  @override
  String get inventoryCategoryDeleteTitle => 'Elimina Categoria';

  @override
  String inventoryCategoryDeleteContent(Object categoryName) {
    return 'Sei sicuro di voler eliminare la Categoria: $categoryName?';
  }

  @override
  String get inventoryItemAddButton => '＋ Aggiungi Nuovo Prodotto';

  @override
  String get inventoryItemAddDialogTitle => 'Aggiungi Nuovo Prodotto';

  @override
  String get inventoryItemEditDialogTitle => 'Modifica Prodotto';

  @override
  String get inventoryItemDeleteTitle => 'Elimina Prodotto';

  @override
  String inventoryItemDeleteContent(Object itemName) {
    return 'Sei sicuro di voler eliminare $itemName?';
  }

  @override
  String get inventoryItemHintName => 'Nome Prodotto';

  @override
  String get inventoryItemHintUnit => 'Unità Prodotto';

  @override
  String get inventoryItemHintStock => 'Numero Inventario Attuale';

  @override
  String get inventoryItemHintPar => 'Quantità di Sicurezza Inventario';

  @override
  String get stockItemTitle => 'Info Prodotto';

  @override
  String get stockItemLabelName => 'Nome Prodotto';

  @override
  String get stockItemLabelMainIngredients => 'Ingredienti Principali';

  @override
  String get stockItemLabelSubsidiaryIngredients => 'Ingredienti Secondari';

  @override
  String stockItemLabelDetails(Object index) {
    return 'Dettagli $index';
  }

  @override
  String get stockItemHintIngredient => 'Ingrediente';

  @override
  String get stockItemHintQty => 'Quantità';

  @override
  String get stockItemHintUnit => 'Unità';

  @override
  String get stockItemHintInstructionsSub => 'Dettagli Istruzioni Secondarie';

  @override
  String get stockItemHintInstructionsNote => 'Dettagli Istruzioni Prodotto';

  @override
  String get stockItemAddSubDialogTitle => 'Aggiungi Ingrediente Secondario';

  @override
  String get stockItemEditSubDialogTitle => 'Edit Subsidiary Category';

  @override
  String get stockItemAddSubHintGroupName => 'Nome Gruppo (es. Guarnizione)';

  @override
  String get stockItemAddOptionTitle => 'Aggiungi Ingrediente Secondario o Dettaglio';

  @override
  String get stockItemAddOptionSub => 'Aggiungi Ingrediente Secondario';

  @override
  String get stockItemAddOptionDetail => 'Aggiungi Dettaglio';

  @override
  String get stockItemDeleteSubTitle => 'Elimina Ingrediente Secondario';

  @override
  String get stockItemDeleteSubContent => 'Sei sicuro di voler eliminare questo ingrediente secondario e le sue note?';

  @override
  String get stockItemDeleteNoteTitle => 'Elimina Nota';

  @override
  String get stockItemDeleteNoteContent => 'Sei sicuro di voler eliminare questa nota?';

  @override
  String get stockCategoryDetailItemTitle => 'Lista Prodotti';

  @override
  String get stockCategoryDetailAddItemButton => '＋ Aggiungi Nuovo Prodotto';

  @override
  String get stockItemDetailDeleteTitle => 'Elimina Prodotto';

  @override
  String stockItemDetailDeleteContent(Object productName) {
    return 'Sei sicuro di voler eliminare $productName?';
  }

  @override
  String get inventoryLogTitle => 'Registri Inventario';

  @override
  String get inventoryLogSearchHint => 'Cerca Articolo Inventario';

  @override
  String get inventoryLogAllDates => 'Tutte le Date';

  @override
  String get inventoryLogDatePickerConfirm => 'Conferma';

  @override
  String get inventoryLogReasonAll => 'TUTTO';

  @override
  String get inventoryLogReasonAdd => 'Aggiungi';

  @override
  String get inventoryLogReasonAdjustment => 'Aggiustamento Inventario';

  @override
  String get inventoryLogReasonWaste => 'Spreco';

  @override
  String get inventoryLogNoRecords => 'Nessun registro trovato.';

  @override
  String get inventoryLogCardUnknownItem => 'Articolo Sconosciuto';

  @override
  String get inventoryLogCardUnknownUser => 'Operatore Sconosciuto';

  @override
  String inventoryLogCardLabelName(Object userName) {
    return 'Nome: $userName';
  }

  @override
  String inventoryLogCardLabelChange(Object adjustment, Object unit) {
    return 'Cambio: $adjustment $unit';
  }

  @override
  String inventoryLogCardLabelStock(Object newStock, Object oldStock) {
    return 'Numero $oldStock→$newStock';
  }

  @override
  String get printerSettingsTitle => 'Impostazioni Hardware';

  @override
  String get printerSettingsListTitle => 'Lista Stampanti';

  @override
  String get printerSettingsNoPrinters => 'Nessuna stampante configurata al momento';

  @override
  String printerSettingsLabelIP(Object ip) {
    return 'IP: $ip';
  }

  @override
  String get printerDialogAddTitle => 'Aggiungi Nuova Stampante';

  @override
  String get printerDialogEditTitle => 'Modifica Info Stampante';

  @override
  String get printerDialogHintName => 'Nome Stampante';

  @override
  String get printerDialogHintIP => 'Indirizzo IP Stampante';

  @override
  String get printerTestConnectionFailed => '❌ Connessione stampante fallita';

  @override
  String get printerTestTicketSuccess => '✅ Biglietto di prova stampato';

  @override
  String get printerCashDrawerOpenSuccess => '✅ Cassetto contanti aperto';

  @override
  String get printerDeleteTitle => 'Elimina Stampante';

  @override
  String printerDeleteContent(Object printerName) {
    return 'Sei sicuro di voler eliminare $printerName?';
  }

  @override
  String get printerTestPrintTitle => '【TEST BIGLIETTO】';

  @override
  String get printerTestPrintSubtitle => 'Test connessione stampante';

  @override
  String get printerTestPrintContent1 => 'Questo è un biglietto di prova,';

  @override
  String get printerTestPrintContent2 => 'Se vedi questo testo,';

  @override
  String get printerTestPrintContent3 => 'Significa che la stampa di testo e immagini è normale.';

  @override
  String get printerTestPrintContent4 => 'Significa che la stampa di testo e immagini è normale.';

  @override
  String get printerTestPrintContent5 => 'Grazie per aver utilizzato Gallery 20.5';

  @override
  String get tableMapAreaSuffix => ' Zona';

  @override
  String get tableMapRemoveTitle => 'Rimuovi Tavolo';

  @override
  String tableMapRemoveContent(Object tableName) {
    return 'Rimuovere \"$tableName\" dalla mappa?';
  }

  @override
  String get tableMapRemoveConfirm => 'Rimuovi';

  @override
  String get tableMapAddDialogTitle => 'Aggiungi Tavolo';

  @override
  String get tableMapShapeCircle => 'Cerchio';

  @override
  String get tableMapShapeSquare => 'Quadrato';

  @override
  String get tableMapShapeRect => 'Rettangolo';

  @override
  String get tableMapAddDialogHint => 'Seleziona N. Tavolo';

  @override
  String get tableMapNoAvailableTables => 'Nessun tavolo disponibile in questa zona.';

  @override
  String get tableMgmtTitle => 'Gestione Tavoli';

  @override
  String get tableMgmtAreaListAddButton => '＋ Aggiungi Nuova Zona';

  @override
  String get tableMgmtAreaListAddTitle => 'Aggiungi Nuova Zona';

  @override
  String get tableMgmtAreaListEditTitle => 'Modifica Zona';

  @override
  String get tableMgmtAreaListHintName => 'Nome Zona';

  @override
  String get tableMgmtAreaListDeleteTitle => 'Elimina Zona';

  @override
  String tableMgmtAreaListDeleteContent(Object areaName) {
    return 'Sei sicuro di voler eliminare la Zona $areaName?';
  }

  @override
  String tableMgmtAreaAddSuccess(Object name) {
    return '✅ Zona \"$name\" aggiunta con successo';
  }

  @override
  String get tableMgmtAreaAddFailure => 'Aggiunta zona fallita';

  @override
  String get tableMgmtTableListAddButton => '＋ Aggiungi Nuovo Tavolo';

  @override
  String get tableMgmtTableListAddTitle => 'Aggiungi Nuovo Tavolo';

  @override
  String get tableMgmtTableListEditTitle => 'Modifica Tavolo';

  @override
  String get tableMgmtTableListHintName => 'Nome Tavolo';

  @override
  String get tableMgmtTableListDeleteTitle => 'Elimina Tavolo';

  @override
  String tableMgmtTableListDeleteContent(Object tableName) {
    return 'Sei sicuro di voler eliminare il Tavolo $tableName?';
  }

  @override
  String get tableMgmtTableAddFailure => 'Aggiunta tavolo fallita';

  @override
  String get tableMgmtTableDeleteFailure => 'Eliminazione tavolo fallita';

  @override
  String get commonSaveFailure => 'Salvataggio dati fallito.';

  @override
  String get commonDeleteFailure => 'Eliminazione elemento fallita.';

  @override
  String get commonNameExists => 'Nome già esistente.';

  @override
  String get menuEditTitle => 'Modifica Menu';

  @override
  String get menuCategoryAddButton => '＋ Aggiungi Nuova Categoria';

  @override
  String get menuDetailAddItemButton => '＋ Aggiungi Nuovo Prodotto';

  @override
  String get menuDeleteCategoryTitle => 'Elimina Categoria';

  @override
  String menuDeleteCategoryContent(Object categoryName) {
    return 'Sei sicuro di voler eliminare $categoryName?';
  }

  @override
  String get menuCategoryAddDialogTitle => 'Aggiungi Nuova Categoria';

  @override
  String get menuCategoryEditDialogTitle => 'Modifica Nome Categoria';

  @override
  String get menuCategoryHintName => 'Nome Categoria';

  @override
  String get menuItemAddDialogTitle => 'Aggiungi Nuovo Prodotto';

  @override
  String get menuItemEditDialogTitle => 'Modifica Prodotto';

  @override
  String get menuItemPriceLabel => 'Prezzo Attuale';

  @override
  String get menuItemMarketPrice => 'Prezzo di Mercato';

  @override
  String get menuItemHintPrice => 'Prezzo Prodotto';

  @override
  String get menuItemLabelMarketPrice => 'Prezzo di Mercato';

  @override
  String menuItemLabelPrice(Object price) {
    return 'Prezzo: $price';
  }

  @override
  String get shiftSetupTitle => 'Configurazione Turni';

  @override
  String get shiftSetupSectionTitle => 'Tipi di Turno Definiti';

  @override
  String get shiftSetupListAddButton => '+ Aggiungi Tipo di Turno';

  @override
  String get shiftSetupSaveButton => 'Salva';

  @override
  String shiftListStartTime(Object endTime, Object startTime) {
    return '$startTime - $endTime';
  }

  @override
  String get shiftDialogAddTitle => 'Aggiungi Tipo di Turno';

  @override
  String get shiftDialogEditTitle => 'Modifica Tipo di Turno';

  @override
  String get shiftDialogHintName => 'Nome Turno';

  @override
  String get shiftDialogLabelStartTime => 'Ora Inizio:';

  @override
  String get shiftDialogLabelEndTime => 'Ora Fine:';

  @override
  String get shiftDialogLabelColor => 'Tag Colore:';

  @override
  String get shiftDialogErrorNameEmpty => 'Si prega di inserire un nome per il turno.';

  @override
  String get shiftDeleteConfirmTitle => 'Conferma Eliminazione';

  @override
  String shiftDeleteConfirmContent(Object shiftName) {
    return 'Sei sicuro di voler eliminare il tipo di turno \"$shiftName\"? Questa modifica deve essere salvata.';
  }

  @override
  String shiftDeleteLocalSuccess(Object shiftName) {
    return 'Tipo di turno \"$shiftName\" eliminato localmente.';
  }

  @override
  String get shiftSaveSuccess => 'Impostazioni turni salvate con successo!';

  @override
  String shiftSaveError(Object error) {
    return 'Salvataggio impostazioni fallito: $error';
  }

  @override
  String shiftLoadError(Object error) {
    return 'Errore caricamento turni: $error';
  }

  @override
  String get commonSuccess => 'Successo';

  @override
  String get commonError => 'Errore';

  @override
  String get punchInSetupTitle => 'Info Timbratura';

  @override
  String get punchInWifiSection => 'Nome Wi-Fi Attuale';

  @override
  String get punchInLocationSection => 'Posizione Attuale';

  @override
  String get punchInLoading => 'Caricamento...';

  @override
  String get punchInErrorPermissionTitle => 'Errore Permesso';

  @override
  String get punchInErrorPermissionContent => 'Si prega di abilitare il permesso di posizione per utilizzare questa funzione.';

  @override
  String get punchInErrorFetchTitle => 'Recupero Info Fallito';

  @override
  String get punchInErrorFetchContent => 'Recupero info Wi-Fi o GPS fallito. Si prega di controllare i permessi e la connessione di rete.';

  @override
  String get punchInSaveFailureTitle => 'Errore';

  @override
  String get punchInSaveFailureContent => 'Recupero informazioni necessarie fallito.';

  @override
  String get punchInSaveSuccessTitle => 'Successo';

  @override
  String get punchInSaveSuccessContent => 'Informazioni timbratura salvate.';

  @override
  String get punchInRegainButton => 'Recupera Wi-Fi & Posizione';

  @override
  String get punchInSaveButton => 'Salva Info Timbratura';

  @override
  String get punchInConfirmOverwriteTitle => 'Conferma Sovrascrittura';

  @override
  String get punchInConfirmOverwriteContent => 'Le informazioni di timbratura esistono già per questo negozio. Vuoi sovrascrivere i dati esistenti?';

  @override
  String get commonOverwrite => 'Sovrascrivi';

  @override
  String get commonOK => 'OK';

  @override
  String get paymentSetupTitle => 'Configurazione Pagamenti';

  @override
  String get paymentSetupMethodsSection => 'Metodi di Pagamento Abilitati';

  @override
  String get paymentSetupFunctionModule => 'Modulo Funzione';

  @override
  String get paymentSetupFunctionDeposit => 'Deposito';

  @override
  String get paymentSetupSaveButton => 'Salva';

  @override
  String paymentSetupLoadError(Object error) {
    return 'Errore caricamento turni: $error';
  }

  @override
  String get paymentSetupSaveSuccess => '✅ Impostazioni salvate';

  @override
  String paymentSetupSaveFailure(Object error) {
    return 'Salvataggio fallito: $error';
  }

  @override
  String get paymentAddDialogTitle => '＋Aggiungi Metodo di Pagamento';

  @override
  String get paymentAddDialogHintName => 'Nome Metodo';

  @override
  String get settlementDetailDailyRevenueSummary => 'Daily Revenue Summary';

  @override
  String get settlementDetailPaymentDetails => 'Payment Details';

  @override
  String get settlementDetailCashCount => 'Cash Count';

  @override
  String get settlementDetailValue => 'Value';

  @override
  String get settlementDetailSummary => 'Summary';

  @override
  String get settlementDetailTotalRevenue => 'Total Revenue:';

  @override
  String get settlementDetailTotalCost => 'Total Cost:';

  @override
  String get settlementDetailCash => 'Cash:';

  @override
  String get settlementDetailTodayDeposit => 'Today\'s Deposit:';

  @override
  String get vaultChangeMoneyStep1 => 'Change Money (Step 1/2)';

  @override
  String get vaultChangeMoneyStep2 => 'Change Money (Step 2/2)';

  @override
  String vaultSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get paymentAddDialogSave => 'Salva';

  @override
  String get costCategoryTitle => 'Categoria di Costo';

  @override
  String get costCategoryAddButton => 'Aggiungi Nuova Categoria';

  @override
  String get costCategoryTypeCOGS => 'Costo del Venduto (COGS)';

  @override
  String get costCategoryTypeOPEX => 'Spese Operative (OPEX)';

  @override
  String get costCategoryAddTitle => 'Aggiungi Categoria';

  @override
  String get costCategoryEditTitle => 'Modifica Categoria';

  @override
  String get costCategoryHintName => 'Nome Categoria';

  @override
  String costCategoryDeleteTitle(Object categoryName) {
    return 'Elimina $categoryName';
  }

  @override
  String get costCategoryDeleteContent => 'Sei sicuro di voler eliminare questa categoria?';

  @override
  String get costCategoryNoticeErrorTitle => 'Errore';

  @override
  String get costCategoryNoticeErrorLoad => 'Caricamento categorie fallito.';

  @override
  String get costCategoryNoticeErrorAdd => 'Aggiunta categoria fallita.';

  @override
  String get costCategoryNoticeErrorUpdate => 'Aggiornamento categoria fallito.';

  @override
  String get costCategoryNoticeErrorDelete => 'Eliminazione categoria fallita.';

  @override
  String get cashRegSetupTitle => 'Configurazione Cassa';

  @override
  String get cashRegSetupSubtitle => 'Si prega di inserire la quantità predefinita di\nogni taglio nel cassetto contanti.';

  @override
  String cashRegSetupTotalLabel(Object totalAmount) {
    return 'Totale: $totalAmount';
  }

  @override
  String get cashRegSetupInputHint => '0';

  @override
  String get cashRegNoticeSaveSuccess => 'Impostazioni fondo cassa salvate con successo!';

  @override
  String cashRegNoticeSaveFailure(Object error) {
    return 'Salvataggio fallito: $error';
  }

  @override
  String cashRegNoticeLoadError(Object error) {
    return 'Errore caricamento impostazioni cassa: $error';
  }

  @override
  String get languageEnglish => 'Inglese';

  @override
  String get languageTraditionalChinese => 'Cinese Tradizionale';

  @override
  String get changePasswordTitle => 'Cambia Password';

  @override
  String get changePasswordOldHint => 'Vecchia Password';

  @override
  String get changePasswordNewHint => 'Nuova Password';

  @override
  String get changePasswordConfirmHint => 'Conferma Nuova Password';

  @override
  String get changePasswordButton => 'Cambia Password';

  @override
  String get passwordValidatorEmptyOld => 'Si prega di inserire la vecchia password';

  @override
  String get passwordValidatorLength => 'La password deve contenere almeno 6 cifre';

  @override
  String get passwordValidatorMismatch => 'Le password non corrispondono';

  @override
  String get passwordErrorReLogin => 'Si prega di accedere di nuovo';

  @override
  String get passwordErrorOldPassword => 'Vecchia password errata';

  @override
  String get passwordErrorUpdateFailed => 'Aggiornamento password fallito';

  @override
  String get passwordSuccess => '✅ Password aggiornata';

  @override
  String passwordFailure(Object error) {
    return '❌ Aggiornamento password fallito: $error';
  }

  @override
  String get languageSimplifiedChinese => 'Cinese Semplificato';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get settingAppearance => 'System Color';

  @override
  String get themeSystem => 'Sistema Colore';

  @override
  String get themeSage => 'Predefinito';

  @override
  String get themeLight => 'Modalità Chiara';

  @override
  String get themeDark => 'Modalità Scura';
}
