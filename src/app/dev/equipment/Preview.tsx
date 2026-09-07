"use client";
import {useState} from "react";
import {EquipmentInput} from "@/components/EquipmentInput";
import {emptyEquipment,equipmentConfigSchema,equipmentSummary,serializeEquipment,readEquipmentConfig} from "@/lib/equipmentConfig";
export function EquipmentPreview(){
 const [value,setValue]=useState(emptyEquipment());
 const [saved,setSaved]=useState("");
 const parsed=equipmentConfigSchema.safeParse(value);
 return <main style={{maxWidth:900,margin:"32px auto",padding:16}}><h1>Equipment input review</h1><EquipmentInput value={value} onChange={setValue}/><button disabled={!parsed.success} onClick={()=>setSaved(serializeEquipment(parsed.success?parsed.data:emptyEquipment()))}>Save preview inputs</button>{saved&&<p role="status">{equipmentSummary(readEquipmentConfig(saved)!)}</p>}<p>Preview only; no account data is changed.</p></main>;
}
