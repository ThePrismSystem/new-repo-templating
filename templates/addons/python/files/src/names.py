def display_name(*parts: str) -> str:
    """Join the parts of a name with single spaces, leaving out blank parts."""
    return " ".join(part.strip() for part in parts if part.strip())
