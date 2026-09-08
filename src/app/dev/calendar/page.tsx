import { notFound } from "next/navigation";
import { CalendarPreview } from "./Preview";

export default function Page() {
  if (process.env.NODE_ENV !== "development") notFound();
  return <CalendarPreview />;
}
