/**
 * Validates a username based on specific criteria
 * @param username - The username to validate
 * @returns Boolean indicating if the username is valid
 */

// export function validateUsername(username: string) {
//   const regex = /^[a-zA-Z0-9]{2,20}$/;
//   return {
//     isValid: regex.test(username),
//     error: regex.test(username) ? null : 'Username must be between 2 and 20 characters, and only letters and numbers are allowed.'
//   };
// }

// export function generateRandomUsername() {
//   const adjectives = ['Happy', 'Lucky', 'Sunny', 'Clever', 'Swift'];
//   const nouns = ['Player', 'Gamer', 'Star', 'Hero', 'Wizard'];
//   const number = Math.floor(Math.random() * 1000);
  
//   const adjective = adjectives[Math.floor(Math.random() * adjectives.length)];
//   const noun = nouns[Math.floor(Math.random() * nouns.length)];
  
//   return `${adjective}${noun}${number}`;
// }
export function validateUsername(username: string): ValidationResult {
    // Trim whitespace
    const trimmedUsername = username.trim();
  
    // Validation rules
    const validationRules = [
      {
        test: (u: string) => u.length >= 2,
        errorMessage: 'Username must be at least 2 characters long'
      },
      {
        test: (u: string) => u.length <= 12,
        errorMessage: 'Username cannot exceed 12 characters'
      },
      {
        test: (u: string) => /^[a-zA-Z0-9_]+$/.test(u),
        errorMessage: 'Username can only contain letters, numbers, and underscores'
      },
      {
        test: (u: string) => !/^\d+$/.test(u),
        errorMessage: 'Username cannot be only numbers'
      }
    ];
  
    // Run validation checks
    for (const rule of validationRules) {
      if (!rule.test(trimmedUsername)) {
        return {
          isValid: false,
          error: rule.errorMessage
        };
      }
    }
  
    // Optional: Check for potentially offensive usernames
    if (containsOffensiveContent(trimmedUsername)) {
      return {
        isValid: false,
        error: 'Username contains inappropriate content'
      };
    }
  
    return {
      isValid: true
    };
  }
  
  /**
   * Checks for potentially offensive usernames
   * @param username - The username to check
   * @returns Boolean indicating if the username contains offensive content
   */
  function containsOffensiveContent(username: string): boolean {
    const offensivePatterns = [
      'admin',
      'moderator',
      'support',
      'fuck',
      'shit',
      'cock',
      'pussy',
      'nigger',
      'asshole'
    ];
  
    const lowercaseUsername = username.toLowerCase();
    return offensivePatterns.some(pattern => 
      lowercaseUsername.includes(pattern)
    );
  }
  
  /**
   * Generate a random username if needed
   * @returns A randomly generated username
   */
  export function generateRandomUsername(): string {
    const adjectives = [
      'Cool', 'Brave', 'Funny', 'Clever', 'Wild', 
      'Smart', 'Quick', 'Sharp', 'Bold', 'Sly'
    ];
    const nouns = [
      'Player', 'Gamer', 'Hero', 'Star', 'Wolf', 
      'Tiger', 'Fox', 'Eagle', 'Lion', 'Shark'
    ];
  
    const randomAdjective = adjectives[Math.floor(Math.random() * adjectives.length)];
    const randomNoun = nouns[Math.floor(Math.random() * nouns.length)];
    const randomNumber = Math.floor(Math.random() * 999);
  
    return `${randomAdjective}${randomNoun}${randomNumber}`;
  }
  
  // Type definitions
  interface ValidationResult {
    isValid: boolean;
    error?: string;
  }
  
  // Export for use in components
  export type { ValidationResult };