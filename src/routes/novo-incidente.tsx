import { createFileRoute, redirect } from "@tanstack/react-router";

export const Route = createFileRoute("/novo-incidente")({
  beforeLoad: () => {
    throw redirect({
      to: "/tratativas/nova",
      replace: true,
    });
  },
});
