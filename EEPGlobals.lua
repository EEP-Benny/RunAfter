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
