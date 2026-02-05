// 🌏 MASTER LOCATION DATA (MAHARASHTRA FOCUSED)
//
// 1. NASHIK Structure:  Taluka -> Gram Panchayat -> Village
// 2. MUMBAI Structure:  Zone   -> Ward           -> Sector/Area

class LocationData {
  static const Map<String, Map<String, Map<String, Map<String, List<String>>>>>
      data = {
    "Maharashtra": {
      // ---------------------------------------------------------
      // 1. NASHIK (Rural/Standard Structure)
      // ---------------------------------------------------------
      "Nashik": {
        "Niphad": {
          "Ozar GP": ["Ozar", "Ozar Air Force Stn", "Dikshi"],
          "Pimpalgaon Baswant GP": ["Pimpalgaon Baswant", "Umberkhed"],
          "Saikheda GP": ["Saikheda", "Chandori"]
        },
        "Sinnar": {
          "Sinnar Rural GP": ["Sinnar", "Musalgaon", "Gonde"],
          "Pangri GP": ["Pangri", "Dubere"]
        },
        "Nashik Taluka": {
          "Girnare GP": ["Girnare", "Gungath"],
          "Deolali GP": ["Deolali", "Lahavit", "Bhagur"]
        },
        "Malegaon": {
          "Saundane GP": ["Saundane", "Tingri"],
          "Vadner GP": ["Vadner Khakurdi"]
        }
      },

      // ---------------------------------------------------------
      // 2. MUMBAI CITY (Urban Structure)
      // Hierarchy Mapped: Taluka -> Zone, GP -> Ward, Village -> Sector
      // ---------------------------------------------------------
      "Mumbai City": {
        "South Mumbai Zone": {
          "Ward A (Colaba)": [
            "Colaba",
            "Cuffe Parade",
            "Navy Nagar",
            "Fort",
            "Nariman Point"
          ],
          "Ward B (Sandhurst Rd)": ["Dongri", "Umarkhadi", "Mandvi"],
          "Ward C (Marine Lines)": ["Marine Lines", "Kalbadevi", "Dhobi Talao"],
          "Ward D (Grant Road)": [
            "Malabar Hill",
            "Breach Candy",
            "Tardeo",
            "Girgaon"
          ]
        },
        "Central Mumbai Zone": {
          "Ward E (Byculla)": ["Byculla", "Mazgaon", "Agripada"],
          "Ward F-South (Parel)": ["Parel", "Sewri", "Lalbaug"],
          "Ward F-North (Matunga)": ["Matunga", "Sion", "Wadala", "Antop Hill"]
        },
        "North Mumbai Zone": {
          "Ward G-South (Worli)": ["Worli", "Lower Parel", "Prabhadevi"],
          "Ward G-North (Dadar)": ["Dadar", "Mahim", "Dharavi"]
        }
      },

      // ---------------------------------------------------------
      // 3. MUMBAI SUBURBAN (Urban Structure)
      // ---------------------------------------------------------
      "Mumbai Suburban": {
        "Western Suburbs": {
          "Ward H-West (Bandra W)": [
            "Bandra West",
            "Khar West",
            "Santa Cruz West"
          ],
          "Ward K-West (Andheri W)": [
            "Andheri West",
            "Versova",
            "Juhu",
            "Vile Parle West"
          ],
          "Ward P-North (Malad)": ["Malad West", "Malad East", "Marve"],
          "Ward R-Central (Borivali)": ["Borivali West", "Gorai", "Eksar"]
        },
        "Eastern Suburbs": {
          "Ward L (Kurla)": ["Kurla", "Saki Naka", "Chunabhatti"],
          "Ward N (Ghatkopar)": [
            "Ghatkopar East",
            "Ghatkopar West",
            "Vikhroli"
          ],
          "Ward S (Bhandup)": ["Bhandup", "Powai", "Kanjurmarg"]
        }
      },

      // ---------------------------------------------------------
      // 4. PUNE (Mixed Structure)
      // ---------------------------------------------------------
      "Pune": {
        // Rural
        "Mulshi": {
          "Paud GP": ["Paud"],
          "Pirangut GP": ["Pirangut", "Pirangut Wadi"]
        },
        // Urban (Mapped to fit 5-level logic)
        "Pune City (PMC)": {
          "Aundh-Baner Ward Office": ["Baner (Sector 1)", "Balewadi", "Aundh"],
          "Kothrud-Bavdhan Ward Office": ["Kothrud", "Bavdhan", "Warje"],
          "Hadapsar-Mundhwa Ward Office": ["Hadapsar", "Magarpatta", "Mundhwa"]
        }
      }
    }
  };

  // --- STATIC GETTERS ---

  static List<String> getStates() {
    final list = data.keys.toList();
    list.sort();
    return list;
  }

  static List<String> getDistricts(String? state) {
    if (state == null || !data.containsKey(state)) return [];
    final list = data[state]!.keys.toList();
    list.sort();
    return list;
  }

  static List<String> getTalukas(String? state, String? district) {
    if (state == null || district == null) return [];
    if (!data.containsKey(state) || !data[state]!.containsKey(district))
      return [];

    final list = data[state]![district]!.keys.toList();
    list.sort();
    return list;
  }

  static List<String> getGPs(String? state, String? district, String? taluka) {
    if (state == null || district == null || taluka == null) return [];
    if (!data.containsKey(state) ||
        !data[state]!.containsKey(district) ||
        !data[state]![district]!.containsKey(taluka)) return [];

    final list = data[state]![district]![taluka]!.keys.toList();
    list.sort();
    return list;
  }

  static List<String> getVillages(
      String? state, String? district, String? taluka, String? gp) {
    if (state == null || district == null || taluka == null || gp == null)
      return [];

    if (!data.containsKey(state) ||
        !data[state]!.containsKey(district) ||
        !data[state]![district]!.containsKey(taluka) ||
        !data[state]![district]![taluka]!.containsKey(gp)) return [];

    final list = data[state]![district]![taluka]![gp] ?? [];

    if (list.isEmpty) return ["Main Area"];

    List<String> sortedList = List.from(list);
    sortedList.sort();
    return sortedList;
  }
}
