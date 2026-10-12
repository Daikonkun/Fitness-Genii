import { notFound } from "next/navigation";
import { StopwatchPreview } from "./preview";

export default function StopwatchReviewPage() {
  if (process.env.NODE_ENV !== "development") notFound();
  return <StopwatchPreview />;
}
