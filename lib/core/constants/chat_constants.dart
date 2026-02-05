class ChatLogic {
  static List<String> getOptions(String role, String orderStatus) {
    // 1. BUYER OPTIONS
    if (role == 'buyer') {
      if (orderStatus == 'Accepted') {
        return [
          "I will arrive today.",
          "I will arrive tomorrow.",
          "Please confirm pickup time.",
        ];
      } else if (orderStatus == 'Ready') {
        return [
          "I am on the way.",
          "I have reached the location.",
          "Please keep the order ready.",
        ];
      } else {
        return ["Thank you!", "Order received."];
      }
    }

    // 2. FARMER / INSPECTOR OPTIONS
    if (role == 'farmer' || role == 'inspector') {
      if (orderStatus == 'Accepted') {
        return [
          "Crop is ready for pickup.",
          "Please arrive between 9–11 AM.",
          "Please arrive between 11–1 PM.",
          "Order is being prepared.",
        ];
      } else if (orderStatus == 'Arrived') {
        return [
          "Please wait for confirmation.",
          "Loading the truck now.",
          "Verifying payment."
        ];
      } else {
        return ["Thank you!", "Drive safely."];
      }
    }

    return [];
  }
}
