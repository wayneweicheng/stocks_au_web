export function confirmReportDeletion(
  title: string,
  jobId: string,
  confirm: (message: string) => boolean = (message) => window.confirm(message),
): boolean {
  if (!confirm(`Delete report "${title}"?\n\nJob ${jobId} will be removed from the report viewer.`)) return false;
  return confirm(`Please confirm again: hide report "${title}" (job ${jobId}) from the report list? The generated artifact remains stored upstream.`);
}
