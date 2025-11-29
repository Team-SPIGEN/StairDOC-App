class NotificationService:
    """Placeholder for push/email integrations."""

    async def send_delivery_update(self, recipient: str, message: str) -> None:
        # Integrate with email, Teams, or MQTT in production
        print(f"[notification] -> {recipient}: {message}")


notification_service = NotificationService()
