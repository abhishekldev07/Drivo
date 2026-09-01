/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />

type SearchRequest = {
  query?: string;
  latitude?: number;
  longitude?: number;
};

type NominatimPlace = {
  place_id?: number;
  display_name?: string;
  lat?: string;
  lon?: string;
  type?: string;
  addresstype?: string;
  address?: Record<string, string>;
};

type SearchResult = {
  id: string;
  title: string;
  subtitle: string;
  latitude: number;
  longitude: number;
  type: string;
};

type CacheEntry = {
  expiresAt: number;
  results: SearchResult[];
};

const cache = new Map<string, CacheEntry>();
let lastUpstreamRequestAt = 0;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });

const finiteCoordinate = (value: unknown, min: number, max: number) =>
  typeof value === "number" && Number.isFinite(value) && value >= min && value <= max;

const shortTitle = (place: NominatimPlace) => {
  const address = place.address ?? {};
  return address.amenity ??
    address.shop ??
    address.tourism ??
    address.leisure ??
    address.building ??
    address.road ??
    address.neighbourhood ??
    address.suburb ??
    address.city ??
    address.town ??
    address.village ??
    place.display_name?.split(",")[0] ??
    "Destination";
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  let payload: SearchRequest;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const query = payload.query?.trim() ?? "";
  if (query.length < 2 || query.length > 120) {
    return json({ error: "Search query must be between 2 and 120 characters" }, 400);
  }

  const hasLocation = finiteCoordinate(payload.latitude, -90, 90) &&
    finiteCoordinate(payload.longitude, -180, 180);
  const cacheKey = `${query.toLowerCase()}|${hasLocation ? `${payload.latitude!.toFixed(2)},${payload.longitude!.toFixed(2)}` : "none"}`;
  const cached = cache.get(cacheKey);
  const now = Date.now();
  if (cached && cached.expiresAt > now) {
    return json({ results: cached.results, cached: true });
  }

  // The public Nominatim service requires an absolute maximum of one upstream
  // request per second and forbids autocomplete. The Flutter client only calls
  // this function after an explicit search submit; this guard adds another
  // layer of protection for the single-user portfolio/demo deployment.
  if (now - lastUpstreamRequestAt < 1100) {
    return json({ error: "Search is cooling down. Try again in a moment." }, 429);
  }
  lastUpstreamRequestAt = now;

  const url = new URL("https://nominatim.openstreetmap.org/search");
  url.searchParams.set("q", query);
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("limit", "6");
  url.searchParams.set("countrycodes", "np");
  url.searchParams.set("dedupe", "1");

  if (hasLocation) {
    const lat = payload.latitude!;
    const lon = payload.longitude!;
    const span = 0.35;
    url.searchParams.set(
      "viewbox",
      `${lon - span},${lat + span},${lon + span},${lat - span}`,
    );
    url.searchParams.set("bounded", "0");
  }

  try {
    const response = await fetch(url, {
      headers: {
        "Accept": "application/json",
        "Accept-Language": "en",
        "User-Agent": "DrivoPortfolio/0.3 (ride-hailing portfolio demo)",
      },
    });

    if (!response.ok) {
      console.error("Nominatim HTTP error", response.status, await response.text());
      return json({ error: "Place search is temporarily unavailable" }, 502);
    }

    const rawPlaces = await response.json() as NominatimPlace[];
    const results = rawPlaces.flatMap((place): SearchResult[] => {
      const latitude = Number(place.lat);
      const longitude = Number(place.lon);
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return [];

      const displayName = place.display_name?.trim() ?? "Destination";
      const title = shortTitle(place).trim();
      return [{
        id: String(place.place_id ?? `${latitude},${longitude}`),
        title,
        subtitle: displayName,
        latitude,
        longitude,
        type: place.addresstype ?? place.type ?? "place",
      }];
    });

    cache.set(cacheKey, {
      expiresAt: now + 10 * 60 * 1000,
      results,
    });

    return json({
      results,
      attribution: "Search data © OpenStreetMap contributors",
    });
  } catch (error) {
    console.error("Place search failed", error);
    return json({ error: "Place search request failed" }, 502);
  }
});
