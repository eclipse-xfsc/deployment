export function wrapText(text: string, wrapNumber: number): string {
  return text.length > wrapNumber ? `${text.slice(0, wrapNumber)}...` : text;
}
