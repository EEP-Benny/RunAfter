---------------------------------------------------------------
-- This file contains dummy implementations of EEP functions --
-- They are used for Intellisense and testing                --
-- Descriptions are taken from the German Lua manual for EEP --
---------------------------------------------------------------

---Bewegt die Achse einer Immobilie oder eines Gleisobjekts.
---**Voraussetzung:** EEP 11.1 Plug-In 1
---@param immoName string Lua-Name der Immobilie als String
---@param axisName string Name der Achse
---@param position integer (positive oder negative) Schrittzahl, um welche die Achse weiter bewegt werden soll. Der Wert 1000 bzw. -1000 bewirkt eine endlose Bewegung. Der Wert 0 stoppt die Bewegung.
---@return boolean ok true, wenn Immobilie und Achse existieren oder false, falls mindestens eins von beidem nicht existiert.
function EEPStructureAnimateAxis(immoName, axisName, position)
  return true
end

---Setzt die Achse einer Immobilie oder eines Gleisobjekts (ohne Animation)
---**Voraussetzung:** EEP 11.1 Plug-In 1
---@param immoName string Lua-Name der Immobilie als String
---@param axisName string Name der Achse
---@param axisPosition number Position, zu der die Achse springen soll als Zahl zwischen 0 und 100
---@return boolean ok true, wenn Immobilie und Achse existieren oder false, falls mindestens eins von beidem nicht existiert.
function EEPStructureSetAxis(immoName, axisName, axisPosition)
  return true
end

---Ermittelt die Position einer Achse der benannten Immobilie oder des Gleisobjekts
---**Voraussetzung:** EEP 11.1 Plug-In 1
---@param immoName string Lua-Name der Immobilie als String
---@param axisName string Name der Achse
---@return boolean ok true, wenn Immobilie und Achse existieren oder false, falls mindestens eins von beidem nicht existiert.
---@return integer axisPosition momentane Position der Achse als Zahl zwischen 0 und 100.
function EEPStructureGetAxis(immoName, axisName)
  return true, 20
end

---Weist einer Immobilie oder einem Landschaftselement einen sog. Tag-Text zu
---**Voraussetzung:** EEP 15
---@param immoName string Lua-Name der Immobilie als String
---@param textToSave string zu speichernder Text
---@return boolean ok true, wenn die Immobilie existiert
function EEPStructureSetTagText(immoName, textToSave)
  return true
end

---Liest den Tag-Text einer Immobilie oder eines Landschaftselementes aus
---**Voraussetzung:** EEP 15
---@param immoName string Lua-Name der Immobilie als String
---@return boolean ok true, wenn die Immobilie existiert
---@return string loadedText Tag-Text, welcher der Immobilie oder dem Landschaftselement mitgegeben wurde
function EEPStructureGetTagText(immoName)
  return true, 'textFromTagText'
end
