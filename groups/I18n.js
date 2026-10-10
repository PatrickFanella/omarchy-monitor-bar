var SUPPORTED_LOCALES = ["en", "de", "es", "fr", "it", "pt-BR", "nl", "pl", "hr", "zh-CN"]

var ENGLISH = {
  "settings.title": "Shelfish settings",
  "settings.shortcut": "Shelfish settings",
  "group.fallback": "Shelfish group",
  "group.newPlaceholder": "New group name",
  "action.create": "Create",
  "action.save": "Save",
  "action.up": "Up",
  "action.down": "Down",
  "action.delete": "Delete",
  "action.add": "Add",
  "action.selected": "Selected",
  "action.remove": "Remove",
  "direction.left": "left",
  "direction.right": "right",
  "label.groupIcon": "GROUP ICON",
  "label.availablePlugins": "AVAILABLE PLUGINS",
  "label.selectedMembers": "SELECTED GROUP MEMBERS"
}

var OVERLAYS = {
  de: {
    "settings.title":"Shelfish-Einstellungen","settings.shortcut":"Shelfish-Einstellungen","group.fallback":"Shelfish-Gruppe","group.newPlaceholder":"Neuer Gruppenname","action.create":"Erstellen","action.save":"Speichern","action.up":"Hoch","action.down":"Runter","action.delete":"Löschen","action.add":"Hinzufügen","action.selected":"Ausgewählt","action.remove":"Entfernen","direction.left":"links","direction.right":"rechts","label.groupIcon":"GRUPPENSYMBOL","label.availablePlugins":"VERFÜGBARE PLUGINS","label.selectedMembers":"MITGLIEDER DER AUSGEWÄHLTEN GRUPPE"
  },
  es: {
    "settings.title":"Configuración de Shelfish","settings.shortcut":"Configuración de Shelfish","group.fallback":"Grupo de Shelfish","group.newPlaceholder":"Nombre del nuevo grupo","action.create":"Crear","action.save":"Guardar","action.up":"Subir","action.down":"Bajar","action.delete":"Eliminar","action.add":"Añadir","action.selected":"Seleccionado","action.remove":"Quitar","direction.left":"izquierda","direction.right":"derecha","label.groupIcon":"ICONO DEL GRUPO","label.availablePlugins":"PLUGINS DISPONIBLES","label.selectedMembers":"MIEMBROS DEL GRUPO SELECCIONADO"
  },
  fr: {
    "settings.title":"Paramètres de Shelfish","settings.shortcut":"Paramètres de Shelfish","group.fallback":"Groupe Shelfish","group.newPlaceholder":"Nom du nouveau groupe","action.create":"Créer","action.save":"Enregistrer","action.up":"Monter","action.down":"Descendre","action.delete":"Supprimer","action.add":"Ajouter","action.selected":"Sélectionné","action.remove":"Retirer","direction.left":"gauche","direction.right":"droite","label.groupIcon":"ICÔNE DU GROUPE","label.availablePlugins":"PLUGINS DISPONIBLES","label.selectedMembers":"MEMBRES DU GROUPE SÉLECTIONNÉ"
  },
  it: {
    "settings.title":"Impostazioni di Shelfish","settings.shortcut":"Impostazioni di Shelfish","group.fallback":"Gruppo Shelfish","group.newPlaceholder":"Nome del nuovo gruppo","action.create":"Crea","action.save":"Salva","action.up":"Su","action.down":"Giù","action.delete":"Elimina","action.add":"Aggiungi","action.selected":"Selezionato","action.remove":"Rimuovi","direction.left":"sinistra","direction.right":"destra","label.groupIcon":"ICONA DEL GRUPPO","label.availablePlugins":"PLUGIN DISPONIBILI","label.selectedMembers":"MEMBRI DEL GRUPPO SELEZIONATO"
  },
  "pt-BR": {
    "settings.title":"Configurações do Shelfish","settings.shortcut":"Configurações do Shelfish","group.fallback":"Grupo Shelfish","group.newPlaceholder":"Nome do novo grupo","action.create":"Criar","action.save":"Salvar","action.up":"Subir","action.down":"Descer","action.delete":"Excluir","action.add":"Adicionar","action.selected":"Selecionado","action.remove":"Remover","direction.left":"esquerda","direction.right":"direita","label.groupIcon":"ÍCONE DO GRUPO","label.availablePlugins":"PLUGINS DISPONÍVEIS","label.selectedMembers":"MEMBROS DO GRUPO SELECIONADO"
  },
  nl: {
    "settings.title":"Shelfish-instellingen","settings.shortcut":"Shelfish-instellingen","group.fallback":"Shelfish-groep","group.newPlaceholder":"Naam van nieuwe groep","action.create":"Aanmaken","action.save":"Opslaan","action.up":"Omhoog","action.down":"Omlaag","action.delete":"Verwijderen","action.add":"Toevoegen","action.selected":"Geselecteerd","action.remove":"Verwijderen","direction.left":"links","direction.right":"rechts","label.groupIcon":"GROEPSPICTOGRAM","label.availablePlugins":"BESCHIKBARE PLUG-INS","label.selectedMembers":"LEDEN VAN DE GESELECTEERDE GROEP"
  },
  pl: {
    "settings.title":"Ustawienia Shelfish","settings.shortcut":"Ustawienia Shelfish","group.fallback":"Grupa Shelfish","group.newPlaceholder":"Nazwa nowej grupy","action.create":"Utwórz","action.save":"Zapisz","action.up":"W górę","action.down":"W dół","action.delete":"Usuń","action.add":"Dodaj","action.selected":"Wybrano","action.remove":"Usuń","direction.left":"w lewo","direction.right":"w prawo","label.groupIcon":"IKONA GRUPY","label.availablePlugins":"DOSTĘPNE WTYCZKI","label.selectedMembers":"CZŁONKOWIE WYBRANEJ GRUPY"
  },
  hr: {
    "settings.title":"Postavke za Shelfish","settings.shortcut":"Postavke za Shelfish","group.fallback":"Grupa Shelfish","group.newPlaceholder":"Naziv nove grupe","action.create":"Izradi","action.save":"Spremi","action.up":"Gore","action.down":"Dolje","action.delete":"Izbriši","action.add":"Dodaj","action.selected":"Odabrano","action.remove":"Ukloni","direction.left":"lijevo","direction.right":"desno","label.groupIcon":"IKONA GRUPE","label.availablePlugins":"DOSTUPNI DODACI","label.selectedMembers":"ČLANOVI ODABRANE GRUPE"
  },
  "zh-CN": {
    "settings.title":"Shelfish 设置","settings.shortcut":"Shelfish 设置","group.fallback":"Shelfish 组","group.newPlaceholder":"新组名称","action.create":"创建","action.save":"保存","action.up":"上移","action.down":"下移","action.delete":"删除","action.add":"添加","action.selected":"已选择","action.remove":"移除","direction.left":"左","direction.right":"右","label.groupIcon":"组图标","label.availablePlugins":"可用插件","label.selectedMembers":"已选组成员"
  }
}

function copyCatalog(source) {
  var result = {}
  Object.keys(source).forEach(function(key) { result[key] = source[key] })
  return result
}

function completeCatalog(overlay) {
  var result = copyCatalog(ENGLISH)
  Object.keys(overlay || {}).forEach(function(key) {
    if (Object.prototype.hasOwnProperty.call(ENGLISH, key)) result[key] = overlay[key]
  })
  return result
}

var CATALOGS = { en: completeCatalog(null) }
SUPPORTED_LOCALES.slice(1).forEach(function(locale) { CATALOGS[locale] = completeCatalog(OVERLAYS[locale]) })

function resolveLocale(localeName) {
  var raw = String(localeName === undefined || localeName === null ? "" : localeName).trim()
  if (!raw || /^(C|POSIX)([.@].*)?$/i.test(raw)) return "en"
  raw = raw.split(".")[0].split("@")[0].replace(/_/g, "-")
  var parts = raw.split("-")
  var language = String(parts[0] || "").toLowerCase()
  if (language === "pt") return "pt-BR"
  if (language === "zh") {
    if (parts.length === 1 || String(parts[1]).toLowerCase() === "cn" || String(parts[1]).toLowerCase() === "hans") return "zh-CN"
    return "en"
  }
  return SUPPORTED_LOCALES.indexOf(language) >= 0 ? language : "en"
}

function interpolate(template, args) {
  var values = args && typeof args === "object" ? args : {}
  return String(template).replace(/\{([A-Za-z][A-Za-z0-9_]*)\}/g, function(match, name) {
    return Object.prototype.hasOwnProperty.call(values, name) && values[name] !== undefined && values[name] !== null
      ? String(values[name]) : match
  })
}

function translate(localeName, key, args) {
  var locale = resolveLocale(localeName)
  var name = String(key === undefined || key === null ? "" : key)
  var template = Object.prototype.hasOwnProperty.call(CATALOGS[locale], name) ? CATALOGS[locale][name]
    : (Object.prototype.hasOwnProperty.call(ENGLISH, name) ? ENGLISH[name] : undefined)
  return interpolate(template === undefined ? name : template, args)
}

if (typeof module !== "undefined") module.exports = {
  SUPPORTED_LOCALES: SUPPORTED_LOCALES,
  ENGLISH: ENGLISH,
  RAW_OVERLAYS: OVERLAYS,
  CATALOGS: CATALOGS,
  resolveLocale: resolveLocale,
  translate: translate
}
