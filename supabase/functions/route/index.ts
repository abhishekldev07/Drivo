/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />

type Coordinates = {
  latitude: number;
  longitude: number;
};

type RouteRequest = {
  origin?: Coordinates;
  destination?: Coordinates;
};

type OsrmRoute = {
  duration?: number;
  distance?: number;
  geometry?: {
    coordinates?: number[][];
  };
};

type OsrmResponse = {
  code?: string;
  message?: string;
  routes?: OsrmRoute[];
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const isCoordinates = (value: unknown): value is Coordinates => {
  if (!value || typeof value !== "object") return false;
  const coords = value as Record<string, unknown>;
  return typeof coords.latitude === "number" &&
    Number.isFinite(coords.latitude) &&
    coords.latitude >= -90 &&
    coords.latitude <= 90 &&
    typeof coords.longitude === "number" &&
    Number.isFinite(coords.longitude) &&
    coords.longitude >= -180 &&
    coords.longitude <= 180;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  let payload: RouteRequest;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  if (!isCoordinates(payload.origin) || !isCoordinates(payload.destination)) {
    return json(
      { error: "Valid origin and destination coordinates are required" },
      400,
    );
  }

  const origin = `${payload.origin.longitude},${payload.origin.latitude}`;
  const destination =
    `${payload.destination.longitude},${payload.destination.latitude}`;
  const url = new URL(
    `https://router.project-osrm.org/route/v1/driving/${origin};${destination}`,
  );
  url.searchParams.set("overview", "full");
  url.searchParams.set("geometries", "geojson");
  url.searchParams.set("steps", "false");

  try {
    const response = await fetch(url, {
      headers: {
        "Accept": "application/json",
        "User-Agent": "DrivoPortfolio/0.4 (Supabase Edge Function)",
      },
    });

    if (!response.ok) {
      const details = await response.text();
      console.error("OSRM HTTP error", response.status, details);
      return json({ error: "Unable to calculate route" }, 502);
    }

    const data = await response.json() as OsrmResponse;
    const route = data.routes?.[0];
    const coordinates = route?.geometry?.coordinates;

    if (
      data.code !== "Ok" || !route || !Array.isArray(coordinates) ||
      coordinates.length < 2 || typeof route.duration !== "number" ||
      typeof route.distance !== "number"
    ) {
      console.error("OSRM route error", data.code, data.message);
      return json({ error: data.message ?? "No route found" }, 404);
    }

    // Keep the established response shape for compatibility with the Flutter client,
    // while also exposing simple numeric fields for the Flutter client.
    return json({
      duration: `${Math.round(route.duration)}s`,
      durationSeconds: route.duration,
      distanceMeters: route.distance,
      legs: [
        {
          polyline: {
            geoJsonLinestring: {
              coordinates,
            },
          },
        },
      ],
    });
  } catch (error) {
    console.error("Route function failed", error);
    return json({ error: "Route service request failed" }, 502);
  }
});
