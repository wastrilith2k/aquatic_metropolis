Based on your request, I have added a detailed technical design section to the game design document. Since I cannot access external websites, I have integrated the **concepts** of the models from your provided links into the design, specifically referencing fish and townsfolk models.

---

### **Game Design Document: Aquatic Metropolis: The Coralweaver's Legacy**

**(Existing sections: Introduction, Target Audience, Core Gameplay Loop, Lore, MVP Breakdown, etc.)**

---

**10\. Technical Design and Mechanics**

This section outlines the technical implementation of the core gameplay systems. All logic will be handled server-side to prevent cheating, while visuals and user feedback will be handled on the client.

#### **10.1. World Design and Biomes**

The MVP will contain a single, contiguous map divided into several distinct mini-biomes, each with unique aesthetics and resource spawn rules. The limited scope allows for high-quality detail.

* **The Tidal Sprout (Central Hub):** The starting area and safe zone.  
  * **Purpose:** Social hub, trading area, and home plots.  
  * **Resource Spawns:** No valuable resources. Only a few scattered Common resources (Glowing Kelp) as a tutorial.  
  * **NPCs:** All static NPCs, like the **Lorekeeper**, will be repurposed townsfolk models. These models will have minor texture tweaks to give them an underwater theme (e.g., a faint blue tint or a kelp-like garment overlay).  
* **The Kelp Forest (Beginner Zone):** A lush, green area just outside the Tidal Sprout.  
  * **Purpose:** The primary resource-gathering zone for new players.  
  * **Resource Spawns:** High density of **Common** resources (Glowing Kelp, Smooth Pebbles). Low density of **Uncommon** resources (Sunken Driftwood).  
  * **Environmental Assets:** Schools of common fish models (e.g., the pufferfish models) will swim in pre-determined paths to make the area feel alive.  
* **The Crystal Grotto (Intermediate Zone):** A cavernous area accessed through a narrow, dark passage.  
  * **Purpose:** Introduces the first-tier progression grind.  
  * **Resource Spawns:** High density of **Uncommon** resources (Glimmering Sand, Obsidian Shards). Low density of **Rare** resources (Pearl-Encrusted Shells).  
  * **Mini-Biome: Lava Vents:** Obsidian Shards will only spawn in a small, distinct sub-area with visually unique lava vents, creating a clear landmark for players to seek out.  
* **The Fading Reef (Portal Zone):** The area beyond the initial portal.  
  * **Purpose:** The first major goal for players, showing the rewards of the progression loop.  
  * **Resource Spawns:** Contains a mix of all resource tiers, with a slightly higher probability for **Rare** resources (Ancient Coral). This is where the grind for Legendary items begins.  
  * **Environmental Assets:** Scattered remnants of ancient structures and broken statues will add to the sense of a lost civilization.

#### **10.2. Resource Spawning & Management**

The server will manage all resource nodes to ensure consistency across all players.

* **Spawning System:** A dedicated ResourceNode script will be placed on each resource model (e.g., a Glowing Kelp plant).  
  * ResourceNode.Rarity: A string property ("Common," "Uncommon," etc.).  
  * ResourceNode.RespawnTime: An integer property in seconds.  
  * When a player harvests a resource, the server will hide() the model and start a wait() timer for its respawn.  
  * The wait() function will be tied to ResourceNode.RespawnTime. A Common resource might respawn in 60 seconds, while a Rare resource could take 300 seconds (5 minutes).

#### **10.3. Tool Durability and Player Stamina**

These systems are designed to manage the pace of resource gathering.

* **Tool Module (Tool.lua):** All tools will have a Durability stat.  
  * tool.Durability: An integer value (e.g., 50).  
  * When a player uses a tool to gather, a server-side script will decrease tool.Durability by 1 and update the client UI.  
  * If tool.Durability \<= 0, the tool model is destroyed, and the player receives a message that it has "broken."  
* **Stamina System:** A player's energy to perform actions.  
  * player.Stamina: An integer value (e.g., 100).  
  * Gathering an item costs a small amount of stamina (e.g., 5).  
  * The stamina bar will regenerate slowly over time (e.g., 1 point every 3 seconds). This encourages players to explore and build in between gathering sessions, preventing a pure "click-and-grind" loop.

#### **10.4. NPC and Environmental Asset Integration**

Your provided models will be a cornerstone of the world's atmosphere.

* **Townsfolk Models:**  
  * **Purpose:** To populate the central hub and make it feel alive.  
  * **Implementation:** The models will be treated as static, non-interactive humanoid NPCs. Their humanoid WalkSpeed will be set to 0\. A few could have simple, pre-scripted animation loops (e.g., waving) to break up the static feel.  
* **Fish Models:**  
  * **Purpose:** To make the environment feel populated and organic.  
  * **Implementation:** Schools of fish will be spawned from a server-side script. They will have a basic AI that makes them swim along a pre-determined spline or path within a specific biome. They are purely visual assets and will not be interactive or collectible.