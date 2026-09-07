import {notFound} from "next/navigation";
import {EquipmentPreview} from "./Preview";
export default function Page(){if(process.env.NODE_ENV!=="development")notFound();return <EquipmentPreview/>;}
