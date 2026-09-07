"use client";
import { equipmentKinds, type EquipmentConfig, type EquipmentKind } from "@/lib/equipmentConfig";

export function EquipmentInput({ value, onChange }: {value: EquipmentConfig; onChange: (value: EquipmentConfig) => void}) {
  const toggle = (kind: EquipmentKind) => {
    const selected = value.selected.includes(kind) ? value.selected.filter(item => item !== kind) : [...value.selected,kind];
    onChange({...value,selected,primary:selected.includes(value.primary) ? value.primary : (selected[0] ?? "bodyweight"),
      kit:selected.includes("kit") ? value.kit ?? {rating:null,unit:"kg",basis:"unknown",tubesPerSide:null} : null,
      dumbbells:selected.some(item=>item === "dumbbells" || item === "full_gym") ? value.dumbbells ?? {weight:0,unit:"kg",count:2} : null});
  };
  return <fieldset className="equipment-input">
    <legend>Equipment & weights / 器材及重量</legend>
    <div className="equipment-options">{Object.entries(equipmentKinds).map(([kind,label]) => <label key={kind}>
      <input type="checkbox" checked={value.selected.includes(kind as EquipmentKind)} onChange={()=>toggle(kind as EquipmentKind)} />{label}
    </label>)}</div>
    <label>Primary equipment / 主力器材<select value={value.primary} onChange={event=>onChange({...value,primary:event.target.value as EquipmentKind})}>
      {!value.selected.length && <option value="bodyweight">Select equipment first / 請先選器材</option>}
      {value.selected.map(kind=><option key={kind} value={kind}>{equipmentKinds[kind]}</option>)}
    </select></label>
    {value.dumbbells && <div className="equipment-weight-row">
      <label>Working weight per dumbbell / 每個啞鈴訓練重量<input type="number" min="0.1" max="500" step="any" value={value.dumbbells.weight || ""} onChange={event=>onChange({...value,dumbbells:{...value.dumbbells!,weight:Number(event.target.value)}})} /></label>
      <label>Dumbbell unit / 啞鈴單位<select value={value.dumbbells.unit} onChange={event=>onChange({...value,dumbbells:{...value.dumbbells!,weight:0,unit:event.target.value as "kg"|"lb"}})}><option value="kg">kg</option><option value="lb">lb</option></select></label>
      <label>Dumbbell quantity / 啞鈴數量<select value={value.dumbbells.count} onChange={event=>onChange({...value,dumbbells:{...value.dumbbells!,count:Number(event.target.value) as 1|2}})}><option value={1}>1</option><option value={2}>2</option></select></label>
    </div>}
    {value.kit && <div className="equipment-kit-controls">
      <p>Padded chest unit, bar, handles and foot straps. Primary kit plans cover chest, back and core.<br />包含胸推背墊、橫桿、手柄及腳套。以套裝為主時，計劃涵蓋胸、背及核心。</p>
      <div className="equipment-weight-row">
        <label>Kit resistance label (optional) / 套裝標示阻力（可留空）<input type="number" min="0.1" max="500" step="any" value={value.kit.rating ?? ""} onChange={event=>onChange({...value,kit:{...value.kit!,rating:event.target.value === "" ? null : Number(event.target.value)}})} /></label>
        <label>Kit rating unit / 阻力單位<select value={value.kit.unit} onChange={event=>onChange({...value,kit:{...value.kit!,rating:null,unit:event.target.value as "kg"|"lb"}})}><option value="kg">kg</option><option value="lb">lb</option></select></label>
        <label>Rating applies to / 標示基準<select value={value.kit.basis} onChange={event=>onChange({...value,kit:{...value.kit!,basis:event.target.value as NonNullable<EquipmentConfig["kit"]>["basis"]}})}><option value="unknown">Not specified / 未註明</option><option value="per_tube">Each tube / 每條管</option><option value="per_side">Each side / 每側</option><option value="total">Whole assembly / 整組</option></select></label>
      </div>
      <label>Chest-unit tubes per side / 胸推組件每側管數<select value={value.kit.tubesPerSide ?? ""} onChange={event=>onChange({...value,kit:{...value.kit!,tubesPerSide:event.target.value ? Number(event.target.value) : null}})}><option value="">Not specified / 未註明</option>{[1,2,3].map(n=><option key={n} value={n}>{n}</option>)}</select></label>
      <small>Band resistance changes with stretch; this label is not a dumbbell-equivalent load. Changing units clears the number so it cannot be silently reinterpreted.<br />拉力隨伸長而變，標示並非等效啞鈴重量。切換單位會清空數值，請重新輸入。</small>
    </div>}
    {value.selected.includes("full_gym") && <p>Gym selection currently uses the supported bodyweight and dumbbell library. Machine, cable and barbell routines are not yet available. Enter the dumbbells you will use above.<br />目前健身房選項使用已支援的徒手及啞鈴動作；尚未提供機械、滑輪及槓鈴訓練。請填寫本次使用的啞鈴重量。</p>}
    <div className="equipment-options">{(["chair","wall"] as const).map(support=><label key={support}><input type="checkbox" checked={value.supports[support]} onChange={event=>onChange({...value,supports:{...value.supports,[support]:event.target.checked}})} />{support === "chair" ? "Stable chair / 穩固椅子" : "Wall support / 牆壁支撐"}</label>)}</div>
  </fieldset>;
}
