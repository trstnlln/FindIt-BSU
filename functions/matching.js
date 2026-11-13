'use strict';
function timestampMillis(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : NaN;
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  if (typeof value === 'string' && value.trim()) return Date.parse(value);
  return NaN;
}
const keywords = text => new Set(String(text || '').toLowerCase().replace(/[^a-z0-9\s]/g,' ').split(/\s+/).filter(word => word.length >= 3 && !['the','and','with','for','this','that','from','have','lost','found','item','please','help','near','inside','outside','around'].includes(word)));
function matchScore(a,b) {
  if (a.archived || b.archived || a.type === b.type || a.status !== 'open' || b.status !== 'open' || a.ownerId === b.ownerId) return 0;
  let score = 0;
  if (a.category && a.category.toLowerCase() === b.category?.toLowerCase()) score += 40;
  if (a.location && a.location.toLowerCase() === b.location?.toLowerCase()) score += 25;
  const days = Math.abs(timestampMillis(a.date) - timestampMillis(b.date)) / 86400000;
  if (days < 3) score += 20; else if (days < 6) score += 15; else if (days < 11) score += 10;
  const words = keywords(`${b.title} ${b.description}`);
  score += Math.min(15, [...keywords(`${a.title} ${a.description}`)].filter(word => words.has(word)).length * 5);
  return score;
}
function matchesSearch(search,item) {
  if (item.archived || item.status !== 'open') return false;
  if (search.category && search.category !== item.category) return false;
  if (search.location && search.location !== item.location) return false;
  const query = String(search.query || '').trim().toLowerCase();
  if (!query) return Boolean(search.category || search.location);
  const text = `${item.title} ${item.description} ${item.category} ${item.location} ${item.specificLocation || ''}`.toLowerCase();
  return query.split(/\s+/).every(word => text.includes(word));
}
module.exports = {matchScore,matchesSearch,timestampMillis};
