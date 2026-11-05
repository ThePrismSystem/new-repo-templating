/**
 * Joins the parts of a name with single spaces, leaving out blank parts.
 *
 * @param {...string} parts
 * @returns {string}
 */
export function displayName(...parts) {
  return parts
    .map((part) => part.trim())
    .filter((part) => part !== "")
    .join(" ");
}
