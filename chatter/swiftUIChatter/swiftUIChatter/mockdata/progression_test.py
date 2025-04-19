import json
import random
from dataclasses import dataclass
from typing import List, Dict, Optional
from datetime import datetime, timedelta

@dataclass
class MockUser:
    id: str
    name: str
    elo_rating: int
    completed_modules: List[str]
    module_attempts: Dict[str, int]  # Track attempts per module
    last_activity: datetime

class ProgressionSystem:
    def __init__(self, course_data_path: str):
        with open(course_data_path, 'r') as f:
            self.course_data = json.load(f)['course']
        
        self.categories = {cat['id']: cat for cat in self.course_data['categories']}
        self.modules = {mod['id']: mod for mod in self.course_data['modules']}
        self.metadata = self.course_data['metadata']
        
    def calculate_elo_gain(self, 
                          module_id: str, 
                          user: MockUser, 
                          checklist_items_completed: int,
                          time_taken: timedelta,
                          is_first_attempt: bool) -> int:
        """Calculate ELO points gained from completing a module."""
        module = self.modules[module_id]
        difficulty = module['difficulty']
        
        # Base calculation from metadata formula
        base_points = difficulty['baseCompletionPoints']
        difficulty_factor = difficulty['score'] / 5
        bonus_multiplier = difficulty['bonusMultiplier']
        checklist_factor = checklist_items_completed / len(module['rubric']['checklistItems'])
        
        # Calculate base ELO gain
        elo_gain = base_points * difficulty_factor * bonus_multiplier * checklist_factor
        
        # Apply bonus conditions
        if checklist_items_completed == len(module['rubric']['checklistItems']):
            elo_gain *= self.metadata['eloCalculation']['bonusConditions'][0]['multiplier']
        
        if time_taken <= timedelta(hours=2.5):  # estimatedCompletionTime from metadata
            elo_gain *= self.metadata['eloCalculation']['bonusConditions'][1]['multiplier']
        
        if is_first_attempt:
            elo_gain *= self.metadata['eloCalculation']['bonusConditions'][2]['multiplier']
        
        # Apply penalty conditions
        if not is_first_attempt:
            elo_gain *= self.metadata['eloCalculation']['penaltyConditions'][0]['multiplier']
        
        if checklist_items_completed < len(module['rubric']['checklistItems']) * 0.7:  # Missing crucial items
            elo_gain *= self.metadata['eloCalculation']['penaltyConditions'][1]['multiplier']
        
        return int(elo_gain)
    
    def can_attempt_module(self, module_id: str, user: MockUser) -> bool:
        """Check if user meets requirements to attempt a module."""
        module = self.modules[module_id]
        return user.elo_rating >= module['requiredEloRating']
    
    def complete_module(self, 
                       module_id: str, 
                       user: MockUser,
                       checklist_items_completed: int,
                       time_taken: timedelta) -> Optional[int]:
        """Process module completion and return ELO points gained."""
        if not self.can_attempt_module(module_id, user):
            return None
            
        is_first_attempt = user.module_attempts.get(module_id, 0) == 0
        user.module_attempts[module_id] = user.module_attempts.get(module_id, 0) + 1
        
        elo_gain = self.calculate_elo_gain(
            module_id=module_id,
            user=user,
            checklist_items_completed=checklist_items_completed,
            time_taken=time_taken,
            is_first_attempt=is_first_attempt
        )
        
        # Update user stats
        user.elo_rating += elo_gain
        if module_id not in user.completed_modules:
            user.completed_modules.append(module_id)
        user.last_activity = datetime.now()
        
        return elo_gain

def generate_mock_users(num_users: int) -> List[MockUser]:
    """Generate a list of mock users with varying initial ELO ratings."""
    users = []
    for i in range(num_users):
        users.append(MockUser(
            id=f"user_{i+1}",
            name=f"Test User {i+1}",
            elo_rating=random.randint(100, 300),  # Random initial ELO
            completed_modules=[],
            module_attempts={},
            last_activity=datetime.now()
        ))
    return users

def test_progression_system():
    # Initialize the progression system
    system = ProgressionSystem('CoursesTYG.json')
    
    # Generate mock users
    users = generate_mock_users(5)
    
    # Test scenarios
    print("\nTesting Progression System:")
    print("-" * 50)
    
    for user in users:
        print(f"\nTesting user: {user.name} (Initial ELO: {user.elo_rating})")
        
        # Try completing modules in order
        for module_id, module in system.modules.items():
            if system.can_attempt_module(module_id, user):
                # Simulate varying completion quality and time
                checklist_items = len(module['rubric']['checklistItems'])
                completed_items = random.randint(int(checklist_items * 0.7), checklist_items)
                time_taken = timedelta(minutes=random.randint(30, 180))
                
                elo_gain = system.complete_module(
                    module_id=module_id,
                    user=user,
                    checklist_items_completed=completed_items,
                    time_taken=time_taken
                )
                
                if elo_gain:
                    print(f"  Completed {module['title']}:")
                    print(f"    - ELO gained: {elo_gain}")
                    print(f"    - New ELO: {user.elo_rating}")
                    print(f"    - Items completed: {completed_items}/{checklist_items}")
                    print(f"    - Time taken: {time_taken}")
                else:
                    print(f"  Could not attempt {module['title']} - ELO too low")
            else:
                print(f"  Skipped {module['title']} - ELO requirement not met")
    
    print("\nFinal Results:")
    print("-" * 50)
    for user in users:
        print(f"{user.name}:")
        print(f"  Final ELO: {user.elo_rating}")
        print(f"  Modules completed: {len(user.completed_modules)}")
        print(f"  Total attempts: {sum(user.module_attempts.values())}")

if __name__ == "__main__":
    test_progression_system() 